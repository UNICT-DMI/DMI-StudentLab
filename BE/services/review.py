from datetime import datetime, timezone

from sqlalchemy import func
from sqlalchemy.orm import Session

from models.review import Review
from models.subject import Subject, UserSubject
from models.user import User, UserAcademicPath

from schemas.review import (
    ReviewCreate,
    ReviewUpdate,
)


def get_review_by_id(
    db: Session,
    review_id: int,
) -> Review | None:
    return (
        db.query(Review)
        .filter(
            Review.id == review_id,
        )
        .first()
    )


def get_review_between_users(
    db: Session,
    reviewer_id: int,
    reviewed_user_id: int,
) -> Review | None:
    return (
        db.query(Review)
        .filter(
            Review.reviewer_id == reviewer_id,
            Review.reviewed_user_id == reviewed_user_id,
        )
        .first()
    )


def get_public_user_reviews(
    db: Session,
    reviewed_user_id: int,
) -> list[Review]:
    return (
        db.query(Review)
        .filter(
            Review.reviewed_user_id == reviewed_user_id,
            Review.moderation_status == "approved",
        )
        .order_by(
            Review.created_at.desc(),
            Review.id.desc(),
        )
        .all()
    )


def get_admin_reviews(
    db: Session,
    moderation_status: str | None = None,
) -> list[Review]:
    query = db.query(Review)

    if moderation_status is not None:
        query = query.filter(
            Review.moderation_status
            == moderation_status,
        )

    return (
        query
        .order_by(
            Review.created_at.desc(),
            Review.id.desc(),
        )
        .all()
    )


def get_pending_reviews(
    db: Session,
) -> list[Review]:
    return get_admin_reviews(
        db,
        moderation_status="pending",
    )


def get_review_summary(
    db: Session,
    reviewed_user_id: int,
) -> dict:
    result = (
        db.query(
            func.avg(
                Review.rating,
            ),
            func.count(
                Review.id,
            ),
        )
        .filter(
            Review.reviewed_user_id
            == reviewed_user_id,
            Review.moderation_status
            == "approved",
        )
        .first()
    )

    average_rating = (
        float(result[0])
        if result
        and result[0] is not None
        else 0.0
    )

    review_count = (
        int(result[1])
        if result
        and result[1] is not None
        else 0
    )

    return {
        "average_rating":
            average_rating,
        "review_count":
            review_count,
    }


def create_review(
    db: Session,
    reviewer: User,
    reviewed_user_id: int,
    data: ReviewCreate,
) -> Review:
    reviewed_user = (
        db.query(User)
        .filter(
            User.id == reviewed_user_id,
        )
        .first()
    )

    if reviewed_user is None:
        raise ValueError(
            "Utente non trovato."
        )

    if not reviewed_user.is_active:
        raise ValueError(
            "Non è possibile recensire un utente non attivo."
        )

    if reviewer.id == reviewed_user.id:
        raise ValueError(
            "Non puoi recensire il tuo stesso profilo."
        )

    existing_review = (
        get_review_between_users(
            db,
            reviewer_id=
                reviewer.id,
            reviewed_user_id=
                reviewed_user_id,
        )
    )

    if existing_review is not None:
        raise ValueError(
            "Hai già recensito questo utente."
        )

    if data.subject_id is not None:
        _validate_review_subject(
            db,
            reviewed_user_id=
                reviewed_user_id,
            subject_id=
                data.subject_id,
        )

    review = Review(
        reviewer_id=
            reviewer.id,
        reviewed_user_id=
            reviewed_user_id,
        subject_id=
            data.subject_id,
        rating=
            data.rating,
        comment=
            data.comment.strip(),
        moderation_status=
            "pending",
        moderated_by=
            None,
        moderated_at=
            None,
    )

    db.add(
        review,
    )

    db.commit()

    db.refresh(
        review,
    )

    return review


def update_review(
    db: Session,
    reviewer: User,
    reviewed_user_id: int,
    data: ReviewUpdate,
) -> Review:
    review = (
        get_review_between_users(
            db,
            reviewer_id=
                reviewer.id,
            reviewed_user_id=
                reviewed_user_id,
        )
    )

    if review is None:
        raise ValueError(
            "Recensione non trovata."
        )

    changed = False

    if (
        data.rating is not None
        and data.rating != review.rating
    ):
        review.rating =  data.rating

        changed =  True

    if data.comment is not None:
        new_comment = data.comment.strip()

        if new_comment != review.comment:
            review.comment = new_comment

            changed =True

    if data.clear_subject:
        if review.subject_id is not None:
            review.subject_id = None

            changed = True

    elif data.subject_id is not None:
        _validate_review_subject(
            db,
            reviewed_user_id=
                reviewed_user_id,
            subject_id=
                data.subject_id,
        )

        if (
            review.subject_id
            != data.subject_id
        ):
            review.subject_id = data.subject_id

            changed = True

    if changed:
        review.moderation_status ="pending"

        review.moderated_by = None

        review.moderated_at =  None

    db.commit()

    db.refresh(
        review,
    )

    return review


def delete_review(
    db: Session,
    reviewer: User,
    reviewed_user_id: int,
) -> None:
    review = (
        get_review_between_users(
            db,
            reviewer_id=
                reviewer.id,
            reviewed_user_id=
                reviewed_user_id,
        )
    )

    if review is None:
        raise ValueError(
            "Recensione non trovata."
        )

    db.delete(
        review,
    )

    db.commit()


def moderate_review(
    db: Session,
    review_id: int,
    moderator: User,
    status: str,
) -> Review:
    if status not in {
        "approved",
        "rejected",
        "hidden",
    }:
        raise ValueError(
            "Stato di moderazione non valido."
        )

    review = (
        get_review_by_id(
            db,
            review_id,
        )
    )

    if review is None:
        raise ValueError(
            "Recensione non trovata."
        )

    if (
        status == "hidden"
        and review.moderation_status
        not in {
            "approved",
            "hidden",
        }
    ):
        raise ValueError(
            "Puoi nascondere solo una recensione già approvata."
        )

    review.moderation_status = status

    review.moderated_by = moderator.id

    review.moderated_at = datetime.now(
            timezone.utc,
        )

    db.commit()

    db.refresh(
        review,
    )

    return review


def restore_hidden_review(
    db: Session,
    review_id: int,
    moderator: User,
) -> Review:
    review = (
        get_review_by_id(
            db,
            review_id,
        )
    )

    if review is None:
        raise ValueError(
            "Recensione non trovata."
        )

    if (
        review.moderation_status
        != "hidden"
    ):
        raise ValueError(
            "La recensione non è nascosta."
        )

    review.moderation_status = "approved"

    review.moderated_by = moderator.id

    review.moderated_at = datetime.now(
            timezone.utc,
        )

    db.commit()

    db.refresh(
        review,
    )

    return review


def serialize_review(
    db: Session,
    review: Review,
) -> dict:
    reviewer = (
        db.query(User)
        .filter(
            User.id
            == review.reviewer_id,
        )
        .first()
    )

    moderator = None

    if review.moderated_by is not None:
        moderator = (
            db.query(User)
            .filter(
                User.id
                == review.moderated_by,
            )
            .first()
        )

    primary_path = None

    if reviewer is not None:
        primary_path_model = (
            db.query(
                UserAcademicPath,
            )
            .filter(
                UserAcademicPath.user_id
                == reviewer.id,
                UserAcademicPath.is_primary
                .is_(True),
            )
            .first()
        )

        if primary_path_model is None:
            primary_path_model = (
                db.query(
                    UserAcademicPath,
                )
                .filter(
                    UserAcademicPath.user_id
                    == reviewer.id,
                    UserAcademicPath.is_current
                    .is_(True),
                )
                .first()
            )

        if primary_path_model is not None:
            primary_path = {
                "id":
                    primary_path_model.id,
                "university":
                    primary_path_model.university,
                "university_code":
                    primary_path_model.university_code,
                "department":
                    primary_path_model.department,
                "department_code":
                    primary_path_model.department_code,
                "course":
                    primary_path_model.course,
                "course_code":
                    primary_path_model.course_code,
                "degree_type":
                    primary_path_model.degree_type,
                "status":
                    primary_path_model.status,
                "verification_status":
                    primary_path_model.verification_status,
                "start_year":
                    primary_path_model.start_year,
                "graduation_year":
                    primary_path_model.graduation_year,
                "is_current":
                    primary_path_model.is_current,
                "is_primary":
                    primary_path_model.is_primary,
            }

    subject_data = None

    if review.subject_id is not None:
        subject = (
            db.query(Subject)
            .filter(
                Subject.id
                == review.subject_id,
            )
            .first()
        )

        if subject is not None:
            subject_data = {
                "id":
                    subject.id,
                "code":
                    subject.code or "",
                "name":
                    subject.name,
            }

    reviewer_first_name = (
        reviewer.first_name
        if reviewer is not None
        else ""
    )

    reviewer_last_name = (
        reviewer.last_name
        if reviewer is not None
        else ""
    )

    reviewer_name = (
        f"{reviewer_first_name} "
        f"{reviewer_last_name}"
    ).strip()

    reviewer_role = (
        reviewer.role
        if reviewer is not None
        else "student"
    )

    moderator_data = None

    if moderator is not None:
        moderator_name = (
            f"{moderator.first_name} "
            f"{moderator.last_name}"
        ).strip()

        moderator_data = {
            "id":
                moderator.id,
            "first_name":
                moderator.first_name,
            "last_name":
                moderator.last_name,
            "name":
                moderator_name,
            "role":
                moderator.role,
        }

    return {
        "id":
            review.id,
        "reviewer_id":
            review.reviewer_id,
        "reviewed_user_id":
            review.reviewed_user_id,
        "rating":
            review.rating,
        "comment":
            review.comment,
        "moderation_status":
            review.moderation_status,
        "moderated_by":
            review.moderated_by,
        "moderated_at":
            review.moderated_at,
        "subject":
            subject_data,
        "reviewer": {
            "id":
                review.reviewer_id,
            "first_name":
                reviewer_first_name,
            "last_name":
                reviewer_last_name,
            "name":
                reviewer_name,
            "role":
                reviewer_role,
            "primary_academic_path":
                primary_path,
        },
        "moderator":
            moderator_data,
        "created_at":
            review.created_at,
        "updated_at":
            review.updated_at,
    }


def serialize_public_user_reviews(
    db: Session,
    reviewed_user_id: int,
    current_user: User | None = None,
) -> dict:
    reviewed_user = (
        db.query(User)
        .filter(
            User.id
            == reviewed_user_id,
        )
        .first()
    )

    if reviewed_user is None:
        raise ValueError(
            "Utente non trovato."
        )

    reviews = (
        get_public_user_reviews(
            db,
            reviewed_user_id=
                reviewed_user_id,
        )
    )

    summary = (
        get_review_summary(
            db,
            reviewed_user_id=
                reviewed_user_id,
        )
    )

    serialized_reviews = [
        serialize_review(
            db,
            review,
        )
        for review in reviews
    ]

    my_review = None

    if (
        current_user is not None
        and current_user.id
        != reviewed_user_id
    ):
        review = (
            get_review_between_users(
                db,
                reviewer_id=
                    current_user.id,
                reviewed_user_id=
                    reviewed_user_id,
            )
        )

        if review is not None:
            my_review = (
                serialize_review(
                    db,
                    review,
                )
            )

    return {
        "reviews":
            serialized_reviews,
        "summary":
            summary,
        "my_review":
            my_review,
    }


def serialize_admin_reviews(
    db: Session,
    moderation_status: str | None = None,
) -> dict:
    reviews = (
        get_admin_reviews(
            db,
            moderation_status=
                moderation_status,
        )
    )

    return {
        "reviews": [
            serialize_review(
                db,
                review,
            )
            for review in reviews
        ],
        "total":
            len(reviews),
    }


def _validate_review_subject(
    db: Session,
    reviewed_user_id: int,
    subject_id: int,
) -> None:
    subject = (
        db.query(Subject)
        .filter(
            Subject.id
            == subject_id,
        )
        .first()
    )

    if subject is None:
        raise ValueError(
            "Materia non trovata."
        )

    user_subject = (
        db.query(UserSubject)
        .filter(
            UserSubject.user_id
            == reviewed_user_id,
            UserSubject.subject_id
            == subject_id,
        )
        .first()
    )

    if user_subject is None:
        raise ValueError(
            "La materia non appartiene al profilo dell'utente recensito."
        )

    if not (
        user_subject.can_help
        or user_subject
        .can_give_private_lessons
    ):
        raise ValueError(
            "La materia non è disponibile per aiuto o lezioni private."
        )