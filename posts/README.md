# Blog Posts

These are pre-written posts ready to publish on developer platforms. Each one tells the DriftGuard story from a different angle, with the architecture diagrams embedded for visual context.

## Posts

| File | Target platform | Angle |
|---|---|---|
| [devto-post.md](devto-post.md) | [dev.to](https://dev.to) | Personal narrative: building it, deploying it, breaking it, and the bugs nobody caught |
| [aws-community-post.md](aws-community-post.md) | AWS Community Builders / community.aws | AWS-focused: services used, security posture, cost, and practical deploy lessons |

## Publishing steps

### dev.to

1. Go to [dev.to/new](https://dev.to/new)
2. Paste the contents of `devto-post.md` (the frontmatter at the top sets the title, tags, and cover image)
3. The cover image and inline images use `raw.githubusercontent.com` URLs pointing at the PNGs in this repo (they render automatically once the repo is public or images are pushed)
4. Preview, then publish

### AWS Community Builders

1. Go to [community.aws](https://community.aws) and create a new post
2. Paste the contents of `aws-community-post.md`
3. Add the images manually from the `docs/architecture/diagrams/` PNGs (upload each one in the editor)
4. Tag with: AWS, EKS, GitOps, Terraform, DevOps, Kubernetes

## Related

- Architecture diagram source and generator: [docs/architecture/](../docs/architecture/README.md)
- Full project: [root README](../README.md)
