from sqlalchemy.orm import configure_mappers

import models.account_deletion_request
import models.group
import models.group_content_report
import models.group_ownership_transfer
import models.group_report
import models.material
import models.notification
import models.profile_error_report
import models.subject
import models.teacher_assignment
import models.user
import models.user_policy_acceptance
import models.user_report


def test_sqlalchemy_mappers_configure_without_warnings():
    configure_mappers()