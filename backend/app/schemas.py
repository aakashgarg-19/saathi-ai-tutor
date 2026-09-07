from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from app.models import ChapterStatus, Role

Language = Literal["en", "hi"]


class ORM(BaseModel):
    model_config = ConfigDict(from_attributes=True)


# --- auth ---
class RegisterIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    email: EmailStr
    password: str = Field(min_length=6, max_length=128)
    role: Role


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class UserOut(ORM):
    id: int
    name: str
    email: str
    role: Role


class TokenOut(BaseModel):
    access_token: str
    user: UserOut


# --- classrooms ---
class ClassroomIn(BaseModel):
    name: str = Field(min_length=2, max_length=120)
    grade: int = Field(ge=1, le=12)


class JoinIn(BaseModel):
    join_code: str = Field(min_length=4, max_length=8)


class ClassroomOut(ORM):
    id: int
    name: str
    grade: int
    join_code: str
    student_count: int = 0


# --- chapters ---
class ChapterOut(ORM):
    id: int
    subject: str
    grade: int
    title: str
    concepts: list[str]
    status: ChapterStatus


# --- doubts ---
class AskIn(BaseModel):
    chapter_id: int
    question: str = Field(min_length=3, max_length=1000)
    language: Language = "en"
    client_id: str | None = Field(default=None, max_length=64)


class SourceOut(BaseModel):
    ref: str
    chunk_id: int
    concept: str
    excerpt: str
    page: int | None


class DoubtOut(ORM):
    id: int
    chapter_id: int
    question: str
    language: str
    answer: str
    concepts: list[str]
    client_id: str | None
    from_cache: bool
    helpful: bool | None
    created_at: datetime
    sources: list[SourceOut] = []


class FeedbackIn(BaseModel):
    helpful: bool


# --- insights ---
class ConceptStat(BaseModel):
    concept: str
    chapter_title: str
    count: int
    unhelpful: int


class RecentDoubt(BaseModel):
    question: str
    student_name: str
    concepts: list[str]
    created_at: datetime


class InsightsOut(BaseModel):
    days: int
    total_doubts: int
    active_students: int
    total_students: int
    helpful_rate: float | None
    concepts: list[ConceptStat]
    recent: list[RecentDoubt]


# --- quizzes ---
class QuizGenerateIn(BaseModel):
    chapter_id: int
    num_questions: int = Field(default=5, ge=3, le=10)
    language: Language = "en"
    concepts: list[str] | None = Field(
        default=None, description="Focus concepts; defaults to the class's most-asked ones"
    )


class QuizQuestion(BaseModel):
    question: str
    options: list[str] = Field(min_length=4, max_length=4)
    answer_index: int = Field(ge=0, le=3)
    concept: str
    explanation: str = ""


class QuizQuestionPublic(BaseModel):
    question: str
    options: list[str]
    concept: str


class QuizOut(ORM):
    id: int
    classroom_id: int
    chapter_id: int
    title: str
    language: str
    created_at: datetime
    questions: list[QuizQuestionPublic]
    my_score: int | None = None
    attempt_count: int = 0


class AttemptIn(BaseModel):
    answers: list[int]


class AttemptResultOut(BaseModel):
    score: int
    total: int
    review: list[QuizQuestion]
    your_answers: list[int]


class StudentResult(BaseModel):
    student_name: str
    score: int
    total: int
    created_at: datetime


class QuizResultsOut(BaseModel):
    quiz_id: int
    attempts: list[StudentResult]
    per_question_correct: list[int]
