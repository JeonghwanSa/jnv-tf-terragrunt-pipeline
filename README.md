# JNV_TF_TERRAGRUNT_PIPELINE

## description
* AWS 계정에 Git Repository 변경에 따라 Terraform을 실행하는 파이프라인을 구성하는 모듈

## example
```
module "jnv_tf_terragrunt_pipeline" {
  source            = "git::https://github.com/JeonghwanSa/jnv-tf-terragrunt-pipeline.git"
  aws_account_alias = "jobis-example"
  repository_name   = "jnv-aws-example-tf"
  pipeline_branch   = "main"
}
```