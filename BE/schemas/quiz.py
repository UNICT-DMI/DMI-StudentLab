from pydantic import BaseModel, Field


class QuizFilterRequest(BaseModel):
    department: str
    course: str
    subject: str

    arguments: list[str] = Field(default_factory=list)

    all_arguments: bool = False

    number_of_questions: int | None = None

    time_limit_seconds: int | None = None


class AnswerRequest(BaseModel):
    id_question: str
    id_choice: str

    department: str
    course: str
    subject: str


class QuestionCountRequest(BaseModel):
    department: str
    course: str
    subject: str

    arguments: list[str] = Field(default_factory=list)

    all_arguments: bool = False


class SubjectRequest(BaseModel):
    department: str
    course: str


class ArgumentsRequest(BaseModel):
    department: str
    course: str
    subject: str