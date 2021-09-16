resource "kubernetes_namespace" "emr-jobs" {
  metadata {
    name = "emr-jobs"
  }
}

resource "kubernetes_role" "emr-containers" {
  depends_on = [kubernetes_namespace.emr-jobs]
  metadata {
    name      = "emr-containers"
    namespace = "emr-jobs"
  }

  rule {
    api_groups = [""]
    resources  = ["namespaces"]
    verbs      = ["get"]
  }
  rule {
    api_groups = [""]
    resources  = ["serviceaccounts", "services", "configmaps", "events", "pods", "pods/log"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "patch", "delete", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", "deployments"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["ingresses"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "annotate", "patch", "label"]
  }
  rule {
    api_groups = ["rbac.authorization.k8s.io"]
    resources  = ["roles", "rolebindings"]
    verbs      = ["get", "list", "watch", "describe", "create", "edit", "delete", "deletecollection", "annotate", "patch", "label"]
  }
}

resource "kubernetes_role_binding" "emr-containers" {
  depends_on = [kubernetes_role.emr-containers]
  metadata {
    name      = "emr-containers"
    namespace = "emr-jobs"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = "emr-containers"
  }
  subject {
    kind      = "User"
    name      = "emr-containers"
    api_group = "rbac.authorization.k8s.io"
  }
}
