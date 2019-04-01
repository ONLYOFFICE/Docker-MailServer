$Config = ".\iRedMail\config"

$SEL = Select-String -AllMatches -Pattern '^export VERSION="1.6.(.*)"$' -Path $Config

$OLD_STR = $SEL.Matches.groups[0].Value

echo $OLD_STR

$OLD_VER = [int]$SEL.Matches.groups[1].Value

echo $OLD_VER

$NEW_VER = $($OLD_VER + 1)

echo $NEW_VER

$NEW_STR = ('export VERSION="1.6.{0}"' -f $NEW_VER)

echo $NEW_STR

$NEW_CONTENT = (Get-Content $Config) -replace $OLD_STR, $NEW_STR

echo $NEW_CONTENT

Set-Content -Path $Config $NEW_CONTENT

$Docker = ".\Dockerfile"

$SEL = Select-String -AllMatches -Pattern '^ARG VERSION="1.6.(.*)"$' -Path $Docker

$OLD_STR = $SEL.Matches.groups[0].Value

$NEW_STR = ('ARG VERSION="1.6.{0}"' -f $NEW_VER)

$NEW_CONTENT = (Get-Content $Docker) -replace $OLD_STR, $NEW_STR

Set-Content -Path $Docker $NEW_CONTENT

$OLD_RELEASE_DATE = Select-String -AllMatches -Pattern '^ARG RELEASE_DATE="(.*)"$' -Path $Docker

$NOW = Get-Date -UFormat "%Y-%m-%d"

$NEW_RELEASE_DATE = ('ARG RELEASE_DATE="{0}"' -f $NOW)

$NEW_CONTENT = (Get-Content $Docker) -replace $OLD_RELEASE_DATE.Matches.groups[0].Value, $NEW_RELEASE_DATE

Set-Content -Path $Docker $NEW_CONTENT