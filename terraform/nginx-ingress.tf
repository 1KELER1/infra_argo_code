resource "helm_release" "external_nginx" {
  name = "external"

  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress"
  create_namespace = true
  version          = "4.12.3"

  values = [file("${path.module}/values/nginx-ingress.yaml")]

  #depends_on = [helm_release.aws_lbc]

  timeout = 1800
  # могут возникнуть проблемы из-за отсутсвия валидации, отключена по причине перегруженности API EKS
  wait                       = false
  disable_openapi_validation = true
  disable_webhooks           = true
  dependency_update          = false
  disable_crd_hooks          = true

}
