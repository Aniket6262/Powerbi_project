# Opening in VS Code and pushing to GitHub

## 1. Open in VS Code
- Unzip the folder somewhere permanent (e.g. `Documents\projects\`).
- In VS Code: **File -> Open Folder…** and pick `ecommerce-sales-analytics`.
- Recommended extensions will be suggested automatically (Python, a PostgreSQL
  client, SQLTools). Install them if you want to run the SQL from inside VS Code.

## 2. (Optional) Build the dashboard first
Follow `powerbi/DASHBOARD_GUIDE.md`, save the `.pbix` into `powerbi/`, and put
page screenshots in `docs/images/` so the README renders them. You can also
push first and add the `.pbix` in a later commit.

## 3. Initialise git and push
Create an empty repo on GitHub first (no README/License, since this folder
already has them). Then, from the project folder:

```bash
git init
git add .
git commit -m "Initial commit: e-commerce SQL + Power BI analytics project"
git branch -M main
git remote add origin https://github.com/<your-username>/ecommerce-sales-analytics.git
git push -u origin main
```

## 4. Later commits (e.g. after adding the .pbix and screenshots)
```bash
git add powerbi/ecommerce_dashboard.pbix docs/images/
git commit -m "Add Power BI dashboard and screenshots"
git push
```

## Notes
- `.pbix` files can be large. GitHub's limit is 100 MB per file; this dashboard
  will be well under that. If it ever exceeds 100 MB, use Git LFS.
- The `data/` CSVs are intentionally committed so the project is reproducible
  for anyone who clones it.
