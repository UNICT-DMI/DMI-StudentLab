
from alembic import op
import sqlalchemy as sa


revision = "2d9f40a8c7b1"
down_revision = "7ab4c2d9e1f0"
branch_labels = None
depends_on = None


def upgrade():
    op.create_table(
        "personal_synced_materials",
        sa.Column("id",sa.Integer(),primary_key=True),
        sa.Column("owner_user_id",sa.Integer(),sa.ForeignKey("users.id",ondelete="CASCADE"),nullable=False,index=True),
        sa.Column("subject_id",sa.Integer(),sa.ForeignKey("subjects.id",ondelete="SET NULL"),nullable=True,index=True),
        sa.Column("university",sa.String(255)),
        sa.Column("department",sa.String(255)),
        sa.Column("course",sa.String(255)),
        sa.Column("subject_name",sa.String(255)),
        sa.Column("original_name",sa.String(255),nullable=False),
        sa.Column("stored_name",sa.String(700),nullable=False,unique=True),
        sa.Column("mime_type",sa.String(255),nullable=False),
        sa.Column("size",sa.BigInteger(),nullable=False),
        sa.Column("file_hash",sa.String(64),nullable=False,index=True),
        sa.Column("version",sa.Integer(),nullable=False,server_default="1"),
        sa.Column("status",sa.String(30),nullable=False,server_default="active",index=True),
        sa.Column("retention_status",sa.String(30),nullable=False,server_default="active",index=True),
        sa.Column("retention_warning_at",sa.DateTime(timezone=True),index=True),
        sa.Column("retention_expires_at",sa.DateTime(timezone=True),index=True),
        sa.Column("last_owner_activity_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.Column("last_downloaded_at",sa.DateTime(timezone=True),index=True),
        sa.Column("deleted_at",sa.DateTime(timezone=True),index=True),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.CheckConstraint("status IN ('active','removed')",name="chk_personal_synced_material_status"),
        sa.CheckConstraint("retention_status IN ('active','warning','expired','deleted')",name="chk_personal_synced_material_retention_status"),
        sa.CheckConstraint("size > 0",name="chk_personal_synced_material_size"),
        sa.UniqueConstraint("owner_user_id","file_hash",name="uq_personal_synced_material_owner_hash"),
    )
    op.create_table(
        "material_shares",
        sa.Column("id",sa.Integer(),primary_key=True),
        sa.Column("sender_user_id",sa.Integer(),sa.ForeignKey("users.id",ondelete="CASCADE"),nullable=False,index=True),
        sa.Column("recipient_user_id",sa.Integer(),sa.ForeignKey("users.id",ondelete="CASCADE"),nullable=False,index=True),
        sa.Column("subject_id",sa.Integer(),sa.ForeignKey("subjects.id",ondelete="SET NULL"),index=True),
        sa.Column("original_name",sa.String(255),nullable=False),
        sa.Column("stored_name",sa.String(700),nullable=False,index=True),
        sa.Column("mime_type",sa.String(255),nullable=False),
        sa.Column("size",sa.BigInteger(),nullable=False),
        sa.Column("file_hash",sa.String(64),nullable=False,index=True),
        sa.Column("message",sa.Text()),
        sa.Column("status",sa.String(30),nullable=False,server_default="pending",index=True),
        sa.Column("cloud_expires_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.Column("accepted_at",sa.DateTime(timezone=True)),
        sa.Column("delivered_at",sa.DateTime(timezone=True)),
        sa.Column("rejected_at",sa.DateTime(timezone=True)),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.CheckConstraint("status IN ('pending','accepted','delivered','rejected','expired')",name="chk_material_share_status"),
        sa.CheckConstraint("size > 0",name="chk_material_share_size"),
        sa.CheckConstraint("sender_user_id != recipient_user_id",name="chk_material_share_different_users"),
    )
    op.create_table(
        "teacher_material_requests",
        sa.Column("id",sa.Integer(),primary_key=True),
        sa.Column("student_user_id",sa.Integer(),sa.ForeignKey("users.id",ondelete="CASCADE"),nullable=False,index=True),
        sa.Column("subject_id",sa.Integer(),sa.ForeignKey("subjects.id",ondelete="CASCADE"),nullable=False,index=True),
        sa.Column("teacher_user_id",sa.Integer(),sa.ForeignKey("users.id",ondelete="SET NULL"),index=True),
        sa.Column("topic",sa.String(255)),
        sa.Column("message",sa.Text(),nullable=False),
        sa.Column("status",sa.String(30),nullable=False,server_default="pending",index=True),
        sa.Column("fulfilled_material_id",sa.Integer(),sa.ForeignKey("teacher_materials.id",ondelete="SET NULL"),index=True),
        sa.Column("resolved_by",sa.Integer(),sa.ForeignKey("users.id",ondelete="SET NULL"),index=True),
        sa.Column("resolved_at",sa.DateTime(timezone=True)),
        sa.Column("created_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.Column("updated_at",sa.DateTime(timezone=True),nullable=False,index=True),
        sa.CheckConstraint("status IN ('pending','fulfilled','rejected','cancelled')",name="chk_teacher_material_request_status"),
    )
    op.add_column("material_publication_requests",sa.Column("attribution_mode",sa.String(20),nullable=False,server_default="anonymous"))
    op.add_column("material_publication_requests",sa.Column("admin_force_anonymous",sa.Boolean(),nullable=False,server_default=sa.false()))
    op.add_column("public_materials",sa.Column("contributor_mode",sa.String(20),nullable=False,server_default="anonymous"))
    op.add_column("public_materials",sa.Column("contributor_display_name",sa.String(255),nullable=True))
    op.add_column("teacher_materials",sa.Column("distribution_mode",sa.String(20),nullable=False,server_default="persistent"))
    op.add_column("teacher_materials",sa.Column("cloud_expires_at",sa.DateTime(timezone=True),nullable=True,index=True))


def downgrade():
    op.drop_column("teacher_materials","cloud_expires_at")
    op.drop_column("teacher_materials","distribution_mode")
    op.drop_column("public_materials","contributor_display_name")
    op.drop_column("public_materials","contributor_mode")
    op.drop_column("material_publication_requests","admin_force_anonymous")
    op.drop_column("material_publication_requests","attribution_mode")
    op.drop_table("teacher_material_requests")
    op.drop_table("material_shares")
    op.drop_table("personal_synced_materials")
