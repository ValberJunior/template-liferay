terraform {
  backend "s3" {
    bucket = "${{ values.terraformStateBucketName }}"
    key    = "${{ values.cluster_name }}/persistente.tfstate"
    region = "${{ values.terraformStateBucketRegion}}"
  }
}
