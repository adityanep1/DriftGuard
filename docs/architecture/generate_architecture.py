#!/usr/bin/env python3
"""Generate the DriftGuard architecture diagrams as code.

The platform is large, so instead of one crowded canvas the architecture is
split into five focused views that share the same styling and edge-color
legend:

  1. two-layer-control      The Terraform (day 0/1) to ArgoCD (day 2) handoff.
  2. aws-infrastructure     The VPC network topology and AWS substrate.
  3. gitops-control-plane   Root_Application, AppProjects, and ApplicationSets.
  4. cicd-delivery          The pull-based build, scan, publish, reconcile flow.
  5. runtime-delivery       In-cluster add-ons, progressive delivery, telemetry.

Each view stays near fifteen nodes so it lays out cleanly in landscape and
stays readable in a README. Regenerate everything with:

    pip install diagrams        # plus the Graphviz system binary (dot)
    python generate_architecture.py

Both PNG (for GitHub previews) and SVG (sharp, selectable) are written to
diagrams/, and every SVG is post-processed so its icons are inlined and the
file renders on any machine.
"""
from __future__ import annotations

import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def ensure_graphviz_on_path() -> None:
    """Add Graphviz to PATH for this process if the dot binary is not found."""
    if shutil.which("dot"):
        return
    for path in ("/usr/bin", "/usr/local/bin", "/opt/homebrew/bin"):
        if os.path.isfile(os.path.join(path, "dot")):
            os.environ["PATH"] = path + os.pathsep + os.environ.get("PATH", "")
            return
    print(
        "warning: Graphviz 'dot' not found. Install graphviz and ensure it is on PATH.",
        file=sys.stderr,
    )


ensure_graphviz_on_path()

from diagrams import Cluster, Diagram, Edge  # noqa: E402
from diagrams.aws.compute import EC2, EKS  # noqa: E402
from diagrams.aws.database import Dynamodb  # noqa: E402
from diagrams.aws.devtools import Codepipeline  # noqa: E402
from diagrams.aws.management import Cloudwatch  # noqa: E402
from diagrams.aws.network import (  # noqa: E402
    ELB,
    InternetGateway,
    NATGateway,
    PrivateSubnet,
    PublicSubnet,
    Route53,
    VPC,
)
from diagrams.aws.security import CertificateManager, IAMRole, KMS, SecretsManager  # noqa: E402
from diagrams.aws.storage import S3  # noqa: E402
from diagrams.k8s.compute import Deployment, Pod  # noqa: E402
from diagrams.k8s.network import Ingress, Service  # noqa: E402
from diagrams.k8s.others import CRD  # noqa: E402
from diagrams.onprem.ci import GithubActions  # noqa: E402
from diagrams.onprem.gitops import ArgoCD  # noqa: E402
from diagrams.onprem.iac import Terraform  # noqa: E402
from diagrams.onprem.logging import Loki  # noqa: E402
from diagrams.onprem.monitoring import Grafana, Prometheus  # noqa: E402
from diagrams.onprem.tracing import Tempo  # noqa: E402
from diagrams.onprem.vcs import Github  # noqa: E402

from embed_icons_in_svg import embed_icons_in_svg  # noqa: E402


# --- Shared styling, reused across every view -----------------------------
GRAPH_ATTR = {
    "dpi": "192",
    "bgcolor": "white",
    "pad": "0.6",
    "splines": "spline",
    "ranksep": "1.5",
    "nodesep": "0.5",
    "fontname": "Helvetica Neue,Helvetica,Arial,sans-serif",
    "fontsize": "18",
}
NODE_ATTR = {
    "fontsize": "11",
    "fontname": "Helvetica Neue,Helvetica,Arial,sans-serif",
}
EDGE_ATTR = {
    "fontsize": "10",
    "fontname": "Helvetica Neue,Helvetica,Arial,sans-serif",
    "penwidth": "1.4",
    "arrowsize": "0.8",
    "color": "#444444",
}

# Edge-color legend, consistent across all five diagrams.
PROVISION = "#333333"   # imperative provisioning by Terraform (day 0/1)
RECONCILE = "#2563EB"   # declarative reconciliation by ArgoCD (day 2)
ASYNC = "#888888"       # supporting, background, or optional flow
SECURE = "#10B981"      # identity, secrets, and policy flow
ERROR = "#cc0000"       # failure, abort, and rollback path

OUTDIR = "diagrams"


def _diagram(name: str, filename: str, direction: str = "LR", **graph_overrides) -> Diagram:
    graph_attr = {**GRAPH_ATTR, **graph_overrides}
    return Diagram(
        name,
        filename=os.path.join(OUTDIR, filename),
        outformat=["png", "svg"],
        show=False,
        direction=direction,
        graph_attr=graph_attr,
        node_attr=NODE_ATTR,
        edge_attr=EDGE_ATTR,
    )


# --- View 1: the two-layer control model ----------------------------------
def build_two_layer_control() -> None:
    with _diagram(
        "DriftGuard | Two-Layer Control Model (Terraform day 0/1 to ArgoCD day 2)",
        "01-two-layer-control",
    ):
        tf = Terraform("Terraform\nday 0/1")

        with Cluster("AWS substrate (imperative)"):
            state = S3("State backend\nS3 + DynamoDB")
            net = VPC("Networking\nVPC/subnets/NAT")
            eks = EKS("EKS cluster\n+ node groups")
            iam = IAMRole("IAM / IRSA")
            ecr = S3("ECR\nimage registry")

        argocd = ArgoCD("ArgoCD\nday 2")
        config = Github("Config_Repo\ndesired state")

        with Cluster("Delivered by ArgoCD (declarative)"):
            addons = CRD("Platform\nadd-ons")
            obs = Prometheus("Observability")
            sec = CRD("Security\npolicies")
            work = Deployment("Workloads\n(Demo_Service)")

        tf >> Edge(color=PROVISION) >> state
        tf >> Edge(color=PROVISION) >> net >> Edge(color=PROVISION) >> eks
        tf >> Edge(color=PROVISION) >> iam
        tf >> Edge(color=PROVISION) >> ecr
        eks >> Edge(color=PROVISION, label="helm install") >> argocd
        argocd >> Edge(color=RECONCILE, label="pull <=180s") >> config
        argocd >> Edge(color=RECONCILE) >> addons
        argocd >> Edge(color=RECONCILE) >> obs
        argocd >> Edge(color=RECONCILE) >> sec
        argocd >> Edge(color=RECONCILE, label="self-heal") >> work


# --- View 2: the AWS network topology --------------------------------------
def build_aws_infrastructure() -> None:
    with _diagram(
        "DriftGuard | AWS Infrastructure and Network Topology (per environment)",
        "02-aws-infrastructure",
        ranksep="2.2",
        nodesep="0.3",
    ):
        dns = Route53("Route53")
        acm = CertificateManager("ACM cert")

        with Cluster("VPC (one per environment)"):
            igw = InternetGateway("Internet\nGateway")
            with Cluster("Public subnets (>= 2 AZ)"):
                alb = ELB("ALB")
                nat = NATGateway("NAT Gateway")
            with Cluster("Private subnets (nodes only)"):
                eks = EKS("EKS control\nplane")
                nodes = EC2("Managed\nnode group")

        ecr = S3("ECR")
        kms = KMS("KMS\nsecret encryption")
        state = S3("S3 state")
        lock = Dynamodb("DynamoDB\nlock table")

        dns >> Edge(color=PROVISION) >> alb
        acm >> Edge(color=SECURE, label="TLS 443") >> alb
        igw >> Edge(color=PROVISION) >> alb
        igw >> Edge(color=PROVISION) >> nat
        nat >> Edge(color=ASYNC, label="egress") >> nodes
        alb >> Edge(color=PROVISION, label="routes") >> nodes
        eks >> Edge(color=PROVISION) >> nodes
        nodes >> Edge(color=ASYNC, label="pull image") >> ecr
        eks >> Edge(color=SECURE) >> kms
        state - Edge(color=ASYNC, style="dashed") - lock


# --- View 3: the GitOps control plane --------------------------------------
def build_gitops_control_plane() -> None:
    with _diagram(
        "DriftGuard | GitOps Control Plane (app-of-apps and ApplicationSets)",
        "03-gitops-control-plane",
        ranksep="2.6",
        nodesep="0.25",
    ):
        root = ArgoCD("Root_Application\napp-of-apps")

        projects = CRD("AppProjects\ndefault-deny")

        with Cluster("ApplicationSets"):
            addons_set = CRD("platform-addons")
            work_set = CRD("workloads")
            obs_set = CRD("observability")

        with Cluster("Add-on Applications"):
            karpenter = Pod("Karpenter")
            albc = Pod("AWS LB\nController")
            eso = Pod("External\nSecrets")
            gatekeeper = Pod("Gatekeeper")

        with Cluster("Workload Applications"):
            dev = Deployment("demo-service\ndev")
            staging = Deployment("demo-service\nstaging")
            prod = Deployment("demo-service\nprod")

        root >> Edge(color=RECONCILE) >> projects
        root >> Edge(color=RECONCILE) >> addons_set
        root >> Edge(color=RECONCILE) >> work_set
        root >> Edge(color=RECONCILE) >> obs_set
        addons_set >> Edge(color=RECONCILE) >> [karpenter, albc, eso, gatekeeper]
        work_set >> Edge(color=RECONCILE) >> [dev, staging, prod]
        projects >> Edge(color=SECURE, style="dashed", label="binds") >> work_set


# --- View 4: the CI/CD delivery flow ---------------------------------------
def build_cicd_delivery() -> None:
    with _diagram(
        "DriftGuard | CI/CD Delivery (pull-based, no direct cluster mutation)",
        "04-cicd-delivery",
    ):
        dev = Github("Developer\npush")
        app_repo = Github("App repo")

        with Cluster("GitHub Actions (OIDC, no static keys)"):
            build = GithubActions("build")
            test = GithubActions("test")
            scan = GithubActions("image scan")
            publish = GithubActions("push to ECR")

        oidc = IAMRole("GitHub OIDC\nrole")
        ecr = S3("ECR")
        config = Github("Config_Repo\nimage tag")
        argocd = ArgoCD("ArgoCD")
        eks = EKS("EKS")

        dev >> Edge(color=PROVISION) >> app_repo >> Edge(color=PROVISION) >> build
        build >> Edge(color=PROVISION) >> test >> Edge(color=PROVISION) >> scan
        scan >> Edge(color=ERROR, style="dashed", label="HIGH/CRIT blocks") >> scan
        scan >> Edge(color=PROVISION) >> publish
        oidc >> Edge(color=SECURE, style="dashed", label="assume-role") >> publish
        publish >> Edge(color=PROVISION, label="commit SHA") >> ecr
        publish >> Edge(color=RECONCILE, label="bump tag") >> config
        config >> Edge(color=RECONCILE, label="pull") >> argocd >> Edge(color=RECONCILE) >> eks


# --- View 5: in-cluster runtime and progressive delivery -------------------
def build_runtime_delivery() -> None:
    with _diagram(
        "DriftGuard | In-Cluster Runtime and Progressive Delivery",
        "05-runtime-delivery",
    ):
        alb = ELB("ALB")
        ingress = Ingress("Ingress")

        with Cluster("Demo_Service Rollout (canary)"):
            stable = Service("stable")
            canary = Service("canary")
            rollout = CRD("Argo Rollout")
            analysis = CRD("Analysis\nTemplate")

        prom = Prometheus("Prometheus")

        with Cluster("Observability (LGTM)"):
            grafana = Grafana("Grafana")
            loki = Loki("Loki")
            tempo = Tempo("Tempo")
            otel = Pod("OTel\nCollector")

        eso = Pod("External\nSecrets")
        sm = SecretsManager("Secrets\nManager")

        alb >> Edge(color=RECONCILE) >> ingress >> Edge(color=RECONCILE) >> stable
        rollout >> Edge(color=RECONCILE, label="20->100%") >> canary
        rollout >> Edge(color=RECONCILE) >> stable
        rollout >> Edge(color=ASYNC, label="query") >> analysis
        analysis >> Edge(color=ASYNC) >> prom
        analysis >> Edge(color=ERROR, style="dashed", label="breach aborts") >> rollout
        stable >> Edge(color=ASYNC, label="metrics/traces") >> otel
        otel >> Edge(color=ASYNC) >> [prom, loki, tempo]
        grafana >> Edge(color=ASYNC, style="dashed") >> prom
        eso >> Edge(color=SECURE, label="materialize") >> sm


def main() -> int:
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(OUTDIR, exist_ok=True)

    builders = [
        build_two_layer_control,
        build_aws_infrastructure,
        build_gitops_control_plane,
        build_cicd_delivery,
        build_runtime_delivery,
    ]
    for builder in builders:
        builder()

    for svg in sorted(os.listdir(OUTDIR)):
        if svg.endswith(".svg"):
            embed_icons_in_svg(os.path.join(OUTDIR, svg))
    print("All architecture diagrams generated in", os.path.abspath(OUTDIR))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
