resource "google_cloud_identity_group" "cloud_identity_group_engineering" {
  display_name         = "gcp engineering (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "enginering@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_backend_engineers" {
  display_name         = "gcp backend-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "backend-engineers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_infra_engineers" {
  display_name         = "gcp infra-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "infra-engineers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_qa_engineers" {
  display_name         = "gcp qa-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "qa-engineers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_deployment_engineers" {
  display_name         = "gcp deployment-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "deployment-engineers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_security_reviewers" {
  display_name         = "gcp security-test-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "security-reviewers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_ml_engineers" {
  display_name         = "gcp ml-engineers (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "ml-engineers@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group" "cloud_identity_group_bi_analyst" {
  display_name         = "gcp bi-analyst (by terraform)"
  initial_group_config = "WITH_INITIAL_OWNER"
  parent               = "customers/C03d8x1ui"
  group_key {
    id = "bi-analyst@spiffy.ai"
  }
  labels = {
    "cloudidentity.googleapis.com/groups.discussion_forum" = ""
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_engineering_owns_backend_engineers" {
  group = google_cloud_identity_group.cloud_identity_group_engineering.id
  preferred_member_key {
    id = google_cloud_identity_group.cloud_identity_group_backend_engineers.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_engineering_owns_infra_engineers" {
  group = google_cloud_identity_group.cloud_identity_group_engineering.id
  preferred_member_key {
    id = google_cloud_identity_group.cloud_identity_group_infra_engineers.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_engineering_owns_deployment_engineers" {
  group = google_cloud_identity_group.cloud_identity_group_engineering.id
  preferred_member_key {
    id = google_cloud_identity_group.cloud_identity_group_deployment_engineers.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_engineering_owns_security_reviewers" {
  group = google_cloud_identity_group.cloud_identity_group_engineering.id
  preferred_member_key {
    id = google_cloud_identity_group.cloud_identity_group_security_reviewers.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}

resource "google_cloud_identity_group_membership" "cloud_identity_group_membership_engineering_owns_ml_engineers" {
  group = google_cloud_identity_group.cloud_identity_group_engineering.id
  preferred_member_key {
    id = google_cloud_identity_group.cloud_identity_group_ml_engineers.group_key[0].id
  }
  roles {
    name = "MEMBER"
  }
}