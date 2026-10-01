$root = "D:\PROJECTS\WEB\mini-choice-engine"
$utf8 = New-Object System.Text.UTF8Encoding($false)
$content = @'
target/
*.class
*.jar
*.log
dependency-reduced-pom.xml
.idea/
*.iml
.vscode/
.DS_Store
'@
[System.IO.File]::WriteAllText("$root\.gitignore", $content, $utf8)
Write-Host ".gitignore created"