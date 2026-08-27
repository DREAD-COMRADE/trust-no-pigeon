# 📌 Git & GitHub Quick Guide Sheet for Trust No Pigeon

This guide sheet explains how to connect this project to **GitHub** and work seamlessly across multiple devices (e.g. your PC and Laptop).

---

## 🛠️ ONE-TIME SETUP: Connect Project to GitHub

### Step 1: Create a Repository on GitHub
1. Go to [https://github.com/new](https://github.com/new).
2. Set **Repository name** to `trust-no-pigeon` (or any name you prefer).
3. Set visibility to **Public** or **Private**.
4. **DO NOT** check "Add a README file" or "Add .gitignore" (we already created them!).
5. Click **Create repository**.

### Step 2: Link your Local Project to GitHub
Open PowerShell or Command Prompt inside `D:\government_pigeons_2026-08-20_17-42-14\pigeon` and run:

```bash
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/trust-no-pigeon.git
git branch -M main
git push -u origin main
```

*(Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username!)*

---

## 💻 DAILY WORKFLOW: Working across PC and Laptop

When working on two systems (e.g. PC and Laptop), follow this simple 2-rule routine:

### Rule 1: BEFORE you start working on a machine (PC or Laptop)
Always download the latest changes from GitHub first:

```bash
git pull
```

### Rule 2: AFTER you finish working on a machine
Always save and upload your progress to GitHub:

```bash
git add .
git commit -m "Describe what changes you made (e.g., added new pigeon behavior)"
git push
```

---

## 📋 ESSENTIAL COMMAND CHEAT SHEET

| Command | Purpose |
| :--- | :--- |
| `git status` | Check which files have been modified, added, or deleted |
| `git add .` | Stage all your changes for commit |
| `git commit -m "message"` | Save a snapshot of your staged changes with a summary message |
| `git push` | Upload your saved commits to GitHub |
| `git pull` | Download the latest updates from GitHub |
| `git log -n 5` | View the last 5 commits history |
| `git diff` | View exact line-by-line code modifications |

---

## 📱 Setting up on your Laptop for the First Time

On your second computer (e.g., your Laptop):

1. Install **Git** from [git-scm.com](https://git-scm.com/) (if not already installed).
2. Open PowerShell and navigate to where you store projects (e.g. `cd D:\Projects`).
3. Clone your GitHub repository:

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/trust-no-pigeon.git
```

4. Open Godot 4.7, click **Import**, select `project.godot` inside the cloned folder, and start working!

---

## 💡 Troubleshooting Tips

- **"Merge Conflict" error when pulling?**
  Run `git status` to see conflicting files, open them in your editor to resolve the markers, then run `git add .` and `git commit -m "fix: resolve merge conflict"`.
- **Forgot if you pushed before switching computers?**
  Run `git status` on your machine. If it says *"Your branch is up to date with 'origin/main'"*, you are all set!
