# GitHub-ზე ატვირთვის ინსტრუქცია

## Step 1: GitHub-ზე Repository-ს შექმნა

1. გადადი github.com-ზე და შედი ანგარიშზე
2. ზედა მარჯვენა კუთხეში **+** → **New repository**
3. **Repository name**: `DWH-Project`
4. **Description**: `Enterprise Data Warehouse with PostgreSQL ETL Pipeline`
5. **Private** → **Create repository**

---

## Step 2: Local Git-ის ინიციალიზაცია

გახსენი **PowerShell** (ან Command Prompt) და გაუშვი:

```powershell
cd "C:\Users\User\Desktop\DWH Project"

git init

git config user.name "DeinUsername"
git config user.email "dein@email.com"
```

---

## Step 3: .gitignore დამატება

თუ არ შეგიქმნია, შექმენი `.gitignore` ფაილი (უკვე გავაკეთე).

---

## Step 4: ფაილების დამატება

```powershell
git add .

git status  # შეამოწმე რა დაემატა
```

---

## Step 5: Commit

```powershell
git commit -m "Initial DWH Project - ETL Pipeline with PostgreSQL"
```

---

## Step 6: Remote-ის დამატება და Push

შექმნისას GitHub გითხრებს:

```
git remote add origin https://github.com/USERNAME/DWH-Project.git
git branch -M main
git push -u origin main
```

ან თუ უკვე შეგიქმნია repository:

```powershell
git remote add origin https://github.com/USERNAME/DWH-Project.git

git push -u origin --all
git push -u origin --tags
```

---

## Step 7: პაროლის შეყვანა

GitHub-მა მოგთხოვს **Personal Access Token** (არა პაროლი!):

1. GitHub → **Settings** → **Developer settings** → **Personal access tokens**
2. **Generate new token** → **Generate new token (classic)**
3. მონიშნე: `repo` checkbox
4. **Copy token** და **paste** გაუკეთე Git-ს

---

## ახალი ცვლილებების Push

მომავალში ცვლილებებისთვის:

```powershell
git add .
git commit -m "რა შეცვალე"
git push
```

---

## ⚠️ � مهم提醒

**არ ატვირთო ეს ფაილები:**

- CSV data files (Დიდი ზომის)
- `.docx` და `.pdf` (თუ არ გჭირდება)
- `*.log` ფაილები
- `~$-` temp files

**Რა უნდა ატვირთო:**

- SQL კოდი
- README.md
- TESTING_GUIDE.md
- .gitignore