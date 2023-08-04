variable "aws_account_alias" {}
variable "pipeline_branch" {}
variable "build_compute_size" {
  default = "BUILD_GENERAL1_LARGE"
}
variable "github_connection_arn" {}
variable "github_fullrepository_id" {}
