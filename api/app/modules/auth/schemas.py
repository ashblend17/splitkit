from typing import Literal

from pydantic import EmailStr, Field

from app.core.schemas import Schema
from app.modules.users.schemas import UserOut


class RegisterIn(Schema):
    name: str = Field(min_length=1, max_length=80)
    email: EmailStr
    password: str = Field(min_length=8, max_length=200)
    currency: Literal["INR", "USD", "EUR"] = "INR"


class LoginIn(Schema):
    email: EmailStr
    password: str


class TokenOut(Schema):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: UserOut
