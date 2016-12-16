#!/bin/bash

# Usage:
# It receives only one parameter with is the version level (major, minor or patch)
#
# Running the script directly:
#    scripts/release.sh minor
#
# Running the npm script
#    npm run release -- major

REPO_URL=$( jq .repository.url package.json | sed 's/\"//g' | sed 's/\.git//g')
REPO_NAME=$( basename $REPO_URL )

if [ "$REPO_NAME" = "null" ] || [ "$REPO_NAME" = "" ]; then
   echo "Could not parse repository url"
   exit 1
fi

VALID_VERSION_LEVELS=(major minor patch)

VERSION_LEVEL=$1

if [ "$VERSION_LEVEL" = "" ]; then
   echo "Version level not provided"
   exit 1
fi

IS_VALID_VERSION_LEVEL=false

for i in "${!VALID_VERSION_LEVELS[@]}"; do
   if [[ "${VALID_VERSION_LEVELS[$i]}" = "${VERSION_LEVEL}" ]]; then
       IS_VALID_VERSION_LEVEL=true
   fi
done

if [ $IS_VALID_VERSION_LEVEL = false ]; then
  echo "Version level is not valid (major minor patch supported)"
  exit 1
fi

TMP_CHANGELOG_FILE="/tmp/$REPO_NAME-TMPCHANGELOG-$RANDOM"
CURR_DATE=`date +%Y-%m-%d`

echo "Release process init"

ORIG_VERSION=$( jq .version package.json | sed 's/\"//g')

echo "Current version" $ORIG_VERSION

NEW_VERSION=$( node_modules/.bin/semver $ORIG_VERSION --preid beta -i $VERSION_LEVEL )
QUOTED_NEW_VERSION="\"$NEW_VERSION\""
NEW_V_VERSION="v$NEW_VERSION"

echo "New version" $NEW_VERSION

echo "Updating package.json"
jq ".version=$QUOTED_NEW_VERSION" package.json > package.json.new

echo "Generating tmp changelog"
echo "#Change Log" > $TMP_CHANGELOG_FILE
echo "" >> $TMP_CHANGELOG_FILE
echo "## [$NEW_V_VERSION](https://github.com/auth0/$REPO_NAME/tree/$NEW_V_VERSION ($CURR_DATE)" >> $TMP_CHANGELOG_FILE
echo "[Full Changelog](https://github.com/auth0/$REPO_NAME/compare/$NEW_V_VERSION...$NEW_V_VERSION)\n" >> $TMP_CHANGELOG_FILE

CHANGELOG_WEBTASK="https://webtask.it.auth0.com/api/run/wt-hernan-auth0_com-0/oss-changelog.js?webtask_no_cache=1&repo=$REPO_NAME&milestone=$NEW_V_VERSION"

curl -f -s -H "Accept: text/markdown" $CHANGELOG_WEBTASK >> $TMP_CHANGELOG_FILE

echo "Updating CHANGELOG.md"

sed "s/\#Change Log//" CHANGELOG.md >> $TMP_CHANGELOG_FILE

echo "Replacing files"

echo "module.exports = { raw: " $NEW_VERSION " };" > src/version.js
mv package.json.new package.json
mv $TMP_CHANGELOG_FILE CHANGELOG.md

git tag $NEW_V_VERSION
git commit -m "Release $NEW_V_VERSION"
git push origin HEAD --tags

