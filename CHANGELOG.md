# Changelog

All notable changes to database-backup will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.13] - 2026-05-19

### Changed

- Bumped awscli to v1.45.10

## [0.0.12] - 2026-05-16

### Changed

- Bumped awscli to v1.45.9

## [0.0.11] - 2026-05-15

### Changed

- Bumped awscli to v1.45.8

## [0.0.10] - 2026-05-14

### Changed

- Bumped awscli to v1.45.7

## [0.0.9] - 2026-05-10

### Added
- GitLab Release is now published automatically on each new tag, with release notes pulled from the matching CHANGELOG section
- Renovate MRs now bump CHANGELOG.md alongside VERSION via the shared bump-version template's BUMP_CHANGELOG option

### Changed
- Source tarballs attached to GitLab Releases now contain only the Dockerfile, runtime scripts, and install metadata (`LICENSE`, `VERSION`, `requirements.txt`, `files/`); CI configs, top-level docs, and bot configuration are excluded via `.gitattributes`
- Removed the `stage: validate` override on `bump-version` — the shared template now pins `stage: .pre` itself
