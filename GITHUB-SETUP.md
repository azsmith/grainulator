# GitHub Repository Setup

This document provides instructions for setting up the Grainulator GitHub repository.

## Quick Setup (Using GitHub CLI)

If you have GitHub CLI installed (`gh`):

```bash
cd ~/projects/grainulator

# Create the repository on GitHub
gh repo create grainulator --public --description "A sophisticated macOS granular synthesis application with multi-track capabilities" --source=. --remote=origin

# Push the initial commit
git push -u origin main
```

## Manual Setup (Using GitHub Web Interface)

### 1. Create Repository on GitHub

1. Go to [https://github.com/new](https://github.com/new)
2. Fill in the repository details:
   - **Repository name**: `grainulator`
   - **Description**: `A sophisticated macOS granular synthesis application with multi-track capabilities`
   - **Visibility**: Public (or Private, your choice)
   - **Initialize repository**: **DO NOT** check any boxes (no README, no .gitignore, no license)
3. Click "Create repository"

### 2. Add Remote and Push

Once the repository is created on GitHub, you'll see instructions. Run these commands:

```bash
cd ~/projects/grainulator

# Add the GitHub repository as remote (replace YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/grainulator.git

# Or if using SSH (recommended):
git remote add origin git@github.com:YOUR_USERNAME/grainulator.git

# Push the initial commit
git branch -M main
git push -u origin main
```

### 3. Configure Repository Settings (Optional)

After pushing, configure your repository on GitHub:

#### General Settings
- **Description**: "A sophisticated macOS granular synthesis application with multi-track capabilities"
- **Website**: (if you have one)
- **Topics**: Add relevant topics for discoverability:
  - `granular-synthesis`
  - `audio`
  - `music`
  - `synthesis`
  - `macos`
  - `swift`
  - `cpp`
  - `monome`
  - `morphagene`

#### About Section
Add these details in the repository's About section:
- ✅ Include the description
- ✅ Add website (if applicable)
- ✅ Add topics (listed above)

#### Branch Protection (Recommended for Collaboration)
1. Go to Settings → Branches
2. Add rule for `main` branch:
   - ✅ Require pull request reviews before merging
   - ✅ Require status checks to pass before merging (when CI is set up)
   - ✅ Include administrators

#### GitHub Pages (Future - for documentation)
- Can be enabled later to host user documentation
- Source: Deploy from `gh-pages` branch or `/docs` folder

## Repository Structure on GitHub

Once pushed, your repository will have:

```
📁 grainulator/
├── 📄 README.md
├── 📄 music-app-specification.md
├── 📄 architecture.md
├── 📄 api-specification.md
├── 📄 ui-design-specification.md
├── 📄 PROJECT-STRUCTURE.md
├── 📄 GITHUB-SETUP.md
├── 📄 .gitignore
├── 📄 .gitattributes
│
├── 📁 Source/
│   ├── 📁 Audio/
│   ├── 📁 Application/
│   ├── 📁 UI/
│   └── 📁 Controllers/
│
├── 📁 Resources/
│   ├── 📁 Assets/
│   ├── 📁 Presets/
│   ├── 📁 Samples/
│   └── 📁 Documentation/
│
├── 📁 Tests/
├── 📁 Build/
└── 📁 Tools/
```

## Keeping Repository Updated

As you make changes to specifications and code, regularly commit and push:

```bash
# Stage changed files
git add <files>

# Or stage all changes
git add .

# Commit with descriptive message
git commit -m "Description of changes"

# Push to GitHub
git push
```

## Example Workflow for Specification Updates

```bash
cd ~/projects/grainulator

# After updating specifications
git add music-app-specification.md ui-design-specification.md
git commit -m "Update granular synthesis specifications

- Added detailed quantization system
- Expanded view mode documentation
- Updated parameter ranges

Co-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"

git push
```

## Setting Up Collaborators (If Applicable)

If you want to add collaborators:

1. Go to Settings → Collaborators
2. Click "Add people"
3. Enter their GitHub username or email
4. Select their permission level:
   - **Read**: View only
   - **Triage**: Read + manage issues/PRs
   - **Write**: Read + push to repository
   - **Maintain**: Write + manage settings (no destructive actions)
   - **Admin**: Full access

## Recommended GitHub Features to Enable

### Issues
- Use GitHub Issues for bug tracking and feature requests
- Create issue templates:
  - Bug report
  - Feature request
  - Question/Discussion

### Projects
- Use GitHub Projects for roadmap planning
- Create project board matching development phases from README

### Discussions
- Enable Discussions for community Q&A
- Categories:
  - General
  - Ideas/Feature Requests
  - Q&A
  - Show and Tell (when users create projects)

### Wiki (Optional)
- Can be used for expanded documentation
- User guides, tutorials, examples

## Continuous Integration (Future)

When ready to set up CI/CD:

### GitHub Actions Workflow Examples

**`.github/workflows/build.yml`** - Build verification
```yaml
name: Build

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Build
        run: xcodebuild -scheme Grainulator -configuration Debug
```

**`.github/workflows/test.yml`** - Run tests
```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Tests
        run: xcodebuild test -scheme Grainulator
```

## Tagging Releases

When ready to create releases:

```bash
# Create and push a tag
git tag -a v1.0.0 -m "Version 1.0.0: Initial release"
git push origin v1.0.0
```

Then create a release on GitHub:
1. Go to Releases
2. Click "Create a new release"
3. Select the tag
4. Add release notes
5. Attach build artifacts (DMG, zip)

## Security

### Dependabot
- GitHub will automatically suggest enabling Dependabot
- Recommended: Enable for security updates

### Code Scanning
- Enable CodeQL analysis (when code is pushed)
- Automatically scans for security vulnerabilities

## License (To Be Determined)

When ready to add a license:

```bash
# Create LICENSE file (choose appropriate license)
# Common options: MIT, Apache 2.0, GPL v3

git add LICENSE
git commit -m "Add LICENSE file"
git push
```

## Resources

- [GitHub Docs](https://docs.github.com)
- [Git Documentation](https://git-scm.com/doc)
- [GitHub CLI](https://cli.github.com) - Optional but helpful tool

---

**Current Status**: Repository initialized locally, ready to push to GitHub
**Last Updated**: 2026-02-01
