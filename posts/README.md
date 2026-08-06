# Blog Posts

These are pre-written posts ready to publish on developer platforms. Each one tells the DriftGuard story from a different angle, with the architecture diagrams embedded for visual context.

## Posts

| File | Target platform | Angle |
|---|---|---|
| [devto-post.md](devto-post.md) | [dev.to](https://dev.to) | Personal narrative: building it, deploying it, breaking it, and the bugs nobody caught |
| [aws-community-post.md](aws-community-post.md) | AWS Community Builders / community.aws | AWS-focused: services used, security posture, cost, and practical deploy lessons |
| [linkedin-post.md](linkedin-post.md) | LinkedIn | Visual carousel with all 5 architecture diagrams, hook about the 7 bugs tests missed |
| [twitter-thread.md](twitter-thread.md) | X (Twitter) | 7-tweet thread, one diagram per tweet, punchy and concrete |

## Publishing steps

### LinkedIn

1. Go to LinkedIn and create a new post
2. Paste the "Final post" section from `linkedin-post.md`
3. Upload the 5 architecture PNGs as a document (carousel) or inline images in order
4. Paste the "First comment" content as your first comment immediately after publishing
5. Add hashtags at the very bottom of the post body

### X (Twitter)

1. Go to X and start a new post
2. Paste Tweet 1 from `twitter-thread.md` (the hook, no image)
3. Click the "+" to add to thread, paste Tweet 2, attach `01-two-layer-control.png`
4. Repeat for Tweets 3-6 (one image each, in order)
5. Add Tweet 7 (closer, no image) as the final tweet in the thread
6. Post the thread
7. Reply to your own thread afterward with the repo link

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
