# Red Hat CNCF Landscape

This repository curates a CNCF landscape view that spotlights the open source projects and products where Red Hat invests, contributes, or builds commercial offerings.  
The data in `landscape.yml` is rendered with [landscape2](https://github.com/cncf/landscape2) to produce a browsable static site that mirrors the public CNCF landscape while adding Red Hat–specific context (for example, differentiating simple community contributions from fully supported products and exposing CNAI groupings).

The repository is intended to be kept close to the upstream CNCF dataset while layering Red Hat metadata on top so that new upstream releases can be merged with minimal friction.

---

## Repository layout

| Path | Purpose |
|------|---------|
| `landscape.yml` | Source of truth for categories, items, and Red Hat metadata (color codes, product descriptions, CNAI tags, etc.). |
| `hosted_logos/` | SVG assets referenced from `landscape.yml`. Store only the logo variants actually used on the landscape. |
| `Containerfile` | Multi-stage build that fetches the CNCF rendering configuration, runs `landscape2 build`, and packages the static site behind nginx for local testing or containerized deployment. |
| `docs/` | Supporting documentation (for example, summary field reference) that clarifies how additional metadata is mapped into the site. |

---

## Editing guidance

1. **Keep upstream structure**  
   - Insert new items alphabetically within their category/subcategory to reduce merge conflicts with CNCF.
   - Preserve all mandatory fields required by the schema noted at the top of `landscape.yml`.

2. **Annotate Red Hat involvement**  
   - Use the `extra.redhat` stanza to describe what Red Hat offers (supported product, operator, integration, etc.).  
   - Apply `color: '#fa2200'` for fully supported Red Hat products; keep `color: '#ee0000'` when we are contributing but not shipping a productized offering.
   - Update the description to explain whether the relationship is a contribution, foundation technology, or customer-facing product.

3. **Capture CNAI placement**  
   - Items that should appear in the Cloud Native AI (CNAI) overlays must list the appropriate `second_path` entry such as `"CNAI / ML Serving"` or `"CNAI / Data Architecture"`.

4. **Logos and assets**  
   - Add only SVG logos that meet CNCF landscape guidelines (transparent background, English wordmark).  
   - Name files using lowercase hyphenated identifiers, and point items to `hosted_logos/<logo>.svg`.

5. **Validate YAML**  
   - Ensure indentation is two spaces per level.  
   - Use block scalars (`|` or `>-`) for multi-line text.  
   - Run `yamllint` or another validator if available before submitting changes.

---

## Building and previewing the site

The provided `Containerfile` builds the static site without requiring direct network access during the render stage. You only need [Podman](https://podman.io) or Docker installed locally.

```bash
# Build the container image
podman build -t redhat-cncf-landscape .

# Run the generated site on http://localhost:8080
podman run --rm -p 8080:8080 redhat-cncf-landscape
```

The multi-stage build performs the following:

1. Fetches this repository plus the canonical CNCF `settings.yml` and `guide.yml`.
2. Runs `landscape2 build` with the local `landscape.yml` and `hosted_logos`.
3. Serves the resulting static assets through nginx configured for single-page app routing.

You can substitute `docker` for `podman` if preferred.

---

## Keeping data in sync with the CSV

The CSV is a convenience list for tracking Red Hat participation levels. A lightweight workflow looks like this:

1. Add or update rows in the CSV when Red Hat joins, graduates, or productizes a CNCF project.  
2. Reconcile the CSV into `landscape.yml`, aligning names and descriptions and updating `extra.redhat` blocks and color values accordingly.  
3. Remove any discrepancies (for example, projects with `"CNCF" != "Yes"` should not appear in the landscape).  
4. Commit both files together so readers can see the provenance of the updates.

Scripts can be written to sanity-check the CSV against `landscape.yml`, but no automation is committed here to keep the repo portable.

---

## Contribution process

1. Create a feature branch.
2. Update `landscape.yml` (and `hosted_logos/` if required) following the editing rules above.
3. Preview the site locally via `podman run` to ensure the new entries render correctly and the CNAI overlays still appear as expected.
4. Submit a pull request summarizing the change (new project, color adjustment, CNAI addition, etc.).  
   - Call out any intentional divergences from upstream CNCF data.  
   - Include validation notes (for example, “previewed locally on Podman” or “yamllint clean”).

---

## Related resources

- [CNCF landscape schema](https://raw.githubusercontent.com/cncf/landscape2/refs/heads/main/docs/config/schema/data.schema.json) — the JSON schema consumed by `landscape.yml`.
- [CNCF landscape2 project](https://github.com/cncf/landscape2) — renderer used by this repo’s Containerfile.

This README should evolve alongside the process. If you discover steps that are missing or tooling that improves validation, please open a PR to document it here.***
