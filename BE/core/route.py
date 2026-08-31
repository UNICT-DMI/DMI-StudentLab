from fastapi import APIRouter, HTTPException

from models.filter import Filter, Answer

from BE.services.quiz_service import (
    shuffle_filter,
    validate_answer,
)


router = APIRouter()


@router.post("/send")
async def send_quest(filter: Filter):

    try:
        question = shuffle_filter(
            filter.department,
            filter.course,
            filter.sub,
            filter.arguments,
            filter.number_of_questions,
        )

        return {
            "success": True,
            "question": question,
        }

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=str(e),
        )


@router.post("/validate")
async def validate_quest(
    answer: Answer,
):

    outcome = validate_answer(
        answer.idQuestion,
        answer.idChoice,
        answer.department,
        answer.sub,
    )

    if outcome is None:
        raise HTTPException(
            status_code=404,
            detail="Question not found",
        )

    return {
        "correct": bool(outcome),

        "message": (
            "Ottimo lavoro!"
            if outcome
            else "Risposta errata."
        ),
    }