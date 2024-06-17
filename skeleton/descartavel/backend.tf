terraform {
  backend "s3" {
    bucket = "${{ values.terraformStateBucketName }}"
    key    = "${{ values.cluster_name }}/descartavel.tfstate"
    region = "${{ values.terraformStateBucketRegion}}"
  }
}
