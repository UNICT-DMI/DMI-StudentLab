from alembic import op
import sqlalchemy as sa


revision = "c42f71ab9d03"
down_revision = "2afa84133894"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("quiz_assignments", sa.Column("execution_mode", sa.String(length=20), server_default="practice", nullable=False))
    op.add_column("quiz_assignments", sa.Column("external_activity_policy", sa.String(length=30), server_default="disabled", nullable=False))
    op.create_index(op.f("ix_quiz_assignments_execution_mode"), "quiz_assignments", ["execution_mode"], unique=False)
    op.create_index(op.f("ix_quiz_assignments_external_activity_policy"), "quiz_assignments", ["external_activity_policy"], unique=False)
    op.create_check_constraint("chk_quiz_assignment_execution_mode", "quiz_assignments", "execution_mode IN ('practice','simulation')")
    op.create_check_constraint("chk_quiz_assignment_external_activity_policy", "quiz_assignments", "external_activity_policy IN ('disabled','structured_devices')")

    op.add_column("quiz_attempts", sa.Column("execution_mode", sa.String(length=20), server_default="practice", nullable=False))
    op.add_column("quiz_attempts", sa.Column("external_activity_policy", sa.String(length=30), server_default="disabled", nullable=False))
    op.add_column("quiz_attempts", sa.Column("completion_reason", sa.String(length=40), nullable=True))
    op.add_column("quiz_attempts", sa.Column("interruption_count", sa.Integer(), server_default="0", nullable=False))
    op.add_column("quiz_attempts", sa.Column("last_interrupted_at", sa.DateTime(timezone=True), nullable=True))
    op.create_index(op.f("ix_quiz_attempts_execution_mode"), "quiz_attempts", ["execution_mode"], unique=False)
    op.create_index(op.f("ix_quiz_attempts_external_activity_policy"), "quiz_attempts", ["external_activity_policy"], unique=False)
    op.create_index(op.f("ix_quiz_attempts_completion_reason"), "quiz_attempts", ["completion_reason"], unique=False)
    op.create_check_constraint("chk_quiz_attempt_execution_mode", "quiz_attempts", "execution_mode IN ('practice','simulation')")
    op.create_check_constraint("chk_quiz_attempt_external_activity_policy", "quiz_attempts", "external_activity_policy IN ('disabled','structured_devices')")
    op.create_check_constraint("chk_quiz_attempt_completion_reason", "quiz_attempts", "completion_reason IS NULL OR completion_reason IN ('completed','time_expired','user_confirmed_exit','app_backgrounded','external_activity_detected','session_abandoned')")
    op.create_check_constraint("chk_quiz_attempt_interruption_count", "quiz_attempts", "interruption_count >= 0")


def downgrade():
    op.drop_constraint("chk_quiz_attempt_interruption_count", "quiz_attempts", type_="check")
    op.drop_constraint("chk_quiz_attempt_completion_reason", "quiz_attempts", type_="check")
    op.drop_constraint("chk_quiz_attempt_external_activity_policy", "quiz_attempts", type_="check")
    op.drop_constraint("chk_quiz_attempt_execution_mode", "quiz_attempts", type_="check")
    op.drop_index(op.f("ix_quiz_attempts_completion_reason"), table_name="quiz_attempts")
    op.drop_index(op.f("ix_quiz_attempts_external_activity_policy"), table_name="quiz_attempts")
    op.drop_index(op.f("ix_quiz_attempts_execution_mode"), table_name="quiz_attempts")
    op.drop_column("quiz_attempts", "last_interrupted_at")
    op.drop_column("quiz_attempts", "interruption_count")
    op.drop_column("quiz_attempts", "completion_reason")
    op.drop_column("quiz_attempts", "external_activity_policy")
    op.drop_column("quiz_attempts", "execution_mode")

    op.drop_constraint("chk_quiz_assignment_external_activity_policy", "quiz_assignments", type_="check")
    op.drop_constraint("chk_quiz_assignment_execution_mode", "quiz_assignments", type_="check")
    op.drop_index(op.f("ix_quiz_assignments_external_activity_policy"), table_name="quiz_assignments")
    op.drop_index(op.f("ix_quiz_assignments_execution_mode"), table_name="quiz_assignments")
    op.drop_column("quiz_assignments", "external_activity_policy")
    op.drop_column("quiz_assignments", "execution_mode")