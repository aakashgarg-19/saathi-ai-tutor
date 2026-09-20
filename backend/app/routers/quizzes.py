from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError

from app.ai import AIError
from app.deps import CurrentUser, Session, Student, Teacher, classroom_for
from app.models import Chapter, ChapterStatus, Quiz, QuizAttempt, Role, User
from app.schemas import (
    AttemptIn,
    AttemptResultOut,
    QuizGenerateIn,
    QuizOut,
    QuizQuestion,
    QuizResultsOut,
    StudentResult,
)
from app.services.quiz import generate_quiz
from app.services.realtime import hub

router = APIRouter(tags=["quizzes"])


def _quiz_out(quiz: Quiz, *, my_score: int | None = None, attempt_count: int = 0) -> QuizOut:
    return QuizOut.model_validate(
        {
            **{
                k: getattr(quiz, k)
                for k in ("id", "classroom_id", "chapter_id", "title", "language", "created_at")
            },
            "questions": quiz.questions,  # answer_index is stripped by QuizQuestionPublic
            "my_score": my_score,
            "attempt_count": attempt_count,
        }
    )


async def _quiz_for(session, quiz_id: int, user: User) -> Quiz:
    quiz = await session.get(Quiz, quiz_id)
    if quiz is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Quiz not found")
    await classroom_for(session, quiz.classroom_id, user)
    return quiz


@router.post(
    "/classrooms/{classroom_id}/quizzes",
    response_model=QuizOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_quiz(classroom_id: int, body: QuizGenerateIn, teacher: Teacher, session: Session):
    classroom = await classroom_for(session, classroom_id, teacher)
    chapter = await session.get(Chapter, body.chapter_id)
    if chapter is None or chapter.status != ChapterStatus.ready:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Chapter not found or still processing")
    try:
        quiz = await generate_quiz(session, classroom, chapter, body)
    except AIError as e:
        raise HTTPException(status.HTTP_503_SERVICE_UNAVAILABLE, str(e)) from e
    return _quiz_out(quiz)


@router.get("/classrooms/{classroom_id}/quizzes", response_model=list[QuizOut])
async def list_quizzes(classroom_id: int, user: CurrentUser, session: Session):
    await classroom_for(session, classroom_id, user)
    quizzes = list(
        await session.scalars(
            select(Quiz).where(Quiz.classroom_id == classroom_id).order_by(Quiz.created_at.desc())
        )
    )
    ids = [q.id for q in quizzes]
    counts = (
        dict(
            (
                await session.execute(
                    select(QuizAttempt.quiz_id, func.count())
                    .where(QuizAttempt.quiz_id.in_(ids))
                    .group_by(QuizAttempt.quiz_id)
                )
            ).all()
        )
        if ids
        else {}
    )
    mine: dict[int, int] = {}
    if user.role == Role.student and ids:
        mine = dict(
            (
                await session.execute(
                    select(QuizAttempt.quiz_id, QuizAttempt.score).where(
                        QuizAttempt.quiz_id.in_(ids), QuizAttempt.student_id == user.id
                    )
                )
            ).all()
        )
    return [
        _quiz_out(q, my_score=mine.get(q.id), attempt_count=counts.get(q.id, 0)) for q in quizzes
    ]


@router.get("/quizzes/{quiz_id}", response_model=QuizOut)
async def get_quiz(quiz_id: int, user: CurrentUser, session: Session):
    return _quiz_out(await _quiz_for(session, quiz_id, user))


@router.post(
    "/quizzes/{quiz_id}/attempts",
    response_model=AttemptResultOut,
    status_code=status.HTTP_201_CREATED,
)
async def attempt_quiz(quiz_id: int, body: AttemptIn, student: Student, session: Session):
    quiz = await _quiz_for(session, quiz_id, student)
    questions = [QuizQuestion.model_validate(q) for q in quiz.questions]
    if len(body.answers) != len(questions):
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY, f"Expected {len(questions)} answers"
        )
    score = sum(a == q.answer_index for a, q in zip(body.answers, questions, strict=True))
    session.add(
        QuizAttempt(
            quiz_id=quiz.id,
            student_id=student.id,
            answers=body.answers,
            score=score,
            total=len(questions),
        )
    )
    try:
        await session.commit()
    except IntegrityError as e:
        raise HTTPException(status.HTTP_409_CONFLICT, "You have already attempted this quiz") from e

    await hub.publish(
        [quiz.classroom_id],
        {
            "type": "quiz_attempted",
            "quiz_id": quiz.id,
            "student_name": student.name,
            "score": score,
            "total": len(questions),
        },
    )
    return AttemptResultOut(
        score=score, total=len(questions), review=questions, your_answers=body.answers
    )


@router.get("/quizzes/{quiz_id}/results", response_model=QuizResultsOut)
async def quiz_results(quiz_id: int, teacher: Teacher, session: Session):
    quiz = await _quiz_for(session, quiz_id, teacher)
    rows = (
        await session.execute(
            select(QuizAttempt, User.name)
            .join(User, User.id == QuizAttempt.student_id)
            .where(QuizAttempt.quiz_id == quiz.id)
            .order_by(QuizAttempt.score.desc())
        )
    ).all()
    per_question = [0] * len(quiz.questions)
    for attempt, _ in rows:
        for i, (answer, q) in enumerate(zip(attempt.answers, quiz.questions, strict=False)):
            per_question[i] += answer == q["answer_index"]
    return QuizResultsOut(
        quiz_id=quiz.id,
        attempts=[
            StudentResult(student_name=name, score=a.score, total=a.total, created_at=a.created_at)
            for a, name in rows
        ],
        per_question_correct=per_question,
    )
