import ipaddress

REQUIRED_TAGS = ("Environment", "Project", "ManagedBy")
ADMINISTRATIVE_PORTS = (22, 3389)
UNRESTRICTED_CIDRS = {"0.0.0.0/0", "::/0"}


def has_complete_required_tags(tags):
    """Return true when every required tag exists and has a non-empty value."""
    return all(isinstance(tags.get(key), str) and tags[key].strip() for key in REQUIRED_TAGS)


def security_group_rule_is_safe(rule):
    """Reject world-open IPv4/IPv6 ingress spanning TCP/UDP admin ports."""
    sources = set(rule.get("cidr_blocks", ())) | set(rule.get("ipv6_cidr_blocks", ()))
    if not sources.intersection(UNRESTRICTED_CIDRS):
        return True
    from_port = int(rule.get("from_port", -1))
    to_port = int(rule.get("to_port", -1))
    return not any(from_port <= port <= to_port for port in ADMINISTRATIVE_PORTS)


def eks_api_allowlist_is_safe(cidrs):
    """Return true only for a non-empty list of valid, restricted API CIDRs."""
    if not cidrs:
        return False
    try:
        networks = [ipaddress.ip_network(cidr, strict=False) for cidr in cidrs]
    except (TypeError, ValueError):
        return False
    return all(str(network) not in UNRESTRICTED_CIDRS for network in networks)


def iam_statement_is_safe(statement):
    """Reject only the dangerous combination of wildcard action and resource."""
    actions = set(statement.get("actions", ()))
    resources = set(statement.get("resources", ()))
    if not actions or not resources:
        return False
    return not ("*" in actions and "*" in resources)


def irsa_trust_is_scoped(trust):
    """Return true when an IRSA trust binds exactly one concrete namespace/SA pair."""
    subjects = trust.get("subjects", ())
    if not isinstance(subjects, (list, tuple)) or len(subjects) != 1:
        return False
    subject = subjects[0]
    prefix = "system:serviceaccount:"
    if not isinstance(subject, str) or not subject.startswith(prefix):
        return False
    parts = subject[len(prefix):].split(":")
    return len(parts) == 2 and all(
        part and part != "*" and not any(character.isspace() for character in part)
        for part in parts
    )


def validate_max_node_count(max_node_count):
    """Validate the environment-wide node cap and return it as an integer."""
    if isinstance(max_node_count, bool) or not isinstance(max_node_count, int):
        raise ValueError("max_node_count must be a whole number")
    if not 1 <= max_node_count <= 1000:
        raise ValueError("max_node_count must be between 1 and 1000")
    return max_node_count


def scaling_request_is_allowed(requested_node_count, max_node_count):
    """Return whether a requested scale count is valid and within the cap."""
    try:
        cap = validate_max_node_count(max_node_count)
    except ValueError:
        return False
    return (
        isinstance(requested_node_count, int)
        and not isinstance(requested_node_count, bool)
        and 0 <= requested_node_count <= cap
    )


def clamp_node_count(requested_node_count, max_node_count):
    """Clamp a valid non-negative scaling result so it never exceeds the cap."""
    cap = validate_max_node_count(max_node_count)
    if isinstance(requested_node_count, bool) or not isinstance(requested_node_count, int) or requested_node_count < 0:
        raise ValueError("requested_node_count must be a non-negative whole number")
    return min(requested_node_count, cap)
