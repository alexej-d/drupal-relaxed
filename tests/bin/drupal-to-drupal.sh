#!/bin/sh

set -ev

mv ~/www/core/modules/system/tests/modules/entity_test ~/www/modules/entity_test
mv ~/www/modules/relaxed/tests/modules/relaxed_test ~/www/modules/relaxed_test

# TODO: Run tests on testing profile with dependencies set up in relaxed_test
php ~/drush.phar --yes --uri=http://localhost:8081 site-install --sites-subdir=8081.localhost --db-url=mysql://root:@127.0.0.1/drupal1 standard
php ~/drush.phar --yes --uri=http://localhost:8081 pm-uninstall rdf

php ~/drush.phar --yes --uri=http://localhost:8080 pm-enable entity_test, relaxed_test || true
php ~/drush.phar --yes --uri=http://localhost:8081 pm-enable entity_test, relaxed_test || true

# Load documents from documents.txt and save them in the 'source' database.
while read document
do
  curl -X POST \
       -H "Content-Type: application/json" \
       -d "$document" \
       admin:admin@localhost:8080/relaxed/default;
done < $TRAVIS_BUILD_DIR/tests/fixtures/documents.txt

php ~/drush.phar cache-rebuild

# Run the replication.
nohup curl -X POST -H "Accept: application/json" -H "Content-Type: application/json" -d '{"source": "http://admin:admin@localhost:8080/relaxed/default", "target": "http://admin:admin@localhost:8081/relaxed/default"}' http://localhost:5984/_replicate &
sleep 120

curl -X GET http://admin:admin@localhost:8081/relaxed/default/_all_docs | tee /tmp/all_docs.txt

#-----------------------------------
sudo cat /var/log/couchdb/couch.log
#-----------------------------------
sudo cat /var/log/apache2/error.log
#-----------------------------------

COUNT=$(wc -l < $TRAVIS_BUILD_DIR/tests/fixtures/documents.txt)
USERS=4
COUNT=$(($COUNT + $USERS));
test 1 -eq $(egrep -c "(\"total_rows\"\:$COUNT)" /tmp/all_docs.txt)
