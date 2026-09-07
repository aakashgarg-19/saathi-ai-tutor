from typing import Annotated

import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import get_session
from app.models import Classroom, ClassroomMember, Role, User
from app.security import decode_token

bearer = HTTPBearer(auto_error=False)

Session = Annotated[AsyncSession, Depends(get_session)]


async def user_from_token(session: AsyncSession, token: str | None) -> User:
    if not token:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Not authenticated")
    try:
        user_id = decode_token(token)
    except jwt.PyJWTError as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token") from e
    user = await session.get(User, user_id)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User no longer exists")
    return user


async def current_user(
    session: Session,
    creds: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)],
) -> User:
    return await user_from_token(session, creds.credentials if creds else None)


def require_role(role: Role):
    async def checker(user: Annotated[User, Depends(current_user)]) -> User:
        if user.role != role:
            raise HTTPException(status.HTTP_403_FORBIDDEN, f"Only {role}s can do this")
        return user

    return checker


CurrentUser = Annotated[User, Depends(current_user)]
Teacher = Annotated[User, Depends(require_role(Role.teacher))]
Student = Annotated[User, Depends(require_role(Role.student))]


async def classroom_for(session: AsyncSession, classroom_id: int, user: User) -> Classroom:
    """Load a classroom the user owns (teacher) or belongs to (student), else 404."""
    classroom = await session.get(Classroom, classroom_id)
    if classroom is not None:
        if user.role == Role.teacher and classroom.teacher_id == user.id:
            return classroom
        if user.role == Role.student:
            member = await session.scalar(
                select(ClassroomMember).where(
                    ClassroomMember.classroom_id == classroom_id,
                    ClassroomMember.student_id == user.id,
                )
            )
            if member:
                return classroom
    raise HTTPException(status.HTTP_404_NOT_FOUND, "Classroom not found")
