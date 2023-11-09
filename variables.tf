variable "aws_account_alias" {}
variable "jnv_region" {
  default = "apne2"
}
variable "jnv_environment" {
  default = "dev"
}
variable "pipeline_branch" {}

variable "build_image" {
  default = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
}
variable "build_image_pull_credentials_type" {
  default = "CODEBUILD"
}
variable "build_privileged_mode" {
  default = true
}
variable "build_compute_size" {
  default = "BUILD_GENERAL1_LARGE"
}
variable "github_connection_arn" {}
variable "github_fullrepository_id" {}
