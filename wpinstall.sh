# install required plugins

#!/bin/bash -e

clear

echo "================================================================="
echo "Beth's Awesome WordPress Installer!!"
echo "================================================================="

# accept the name of our website
echo "Site Name: "
read -e sitename

# accept user input for the user name
echo "Username: "
read -e wpuser

# accept user input for the user name
echo "Password: "
read -e wppass

# accept user input for the user email
echo "Admin Email: "
read -e wpemail

# accept user input for the site address
echo "Site Address: "
read -e siteaddress

# accept user input for the databse name
echo "Database Name: "
read -e dbname

# accept a comma separated list of pages
echo "Add Pages: "
read -e allpages

# accept a comma separated list of categories
echo "Add Categories: "
read -e allcategories

# add a simple yes/no confirmation before we proceed
echo "Run Install? (y/n)"
read -e run

# if the user didn't say no, then go ahead an install
if [ "$run" == n ] ; then
exit
else

touch wp-cli.yml
echo "path: wp" | tee wp-cli.yml
mkdir app && cd app
touch index.php
echo "<?php // silence is golden" | tee index.php
mkdir media mu-plugins plugins themes
cd plugins
touch index.php
echo "<?php // silence is golden" | tee index.php
cd ..
cd themes
touch index.php
echo "<?php // silence is golden" | tee index.php
cd ..
cd ..
mkdir wp && cd wp

# download the WordPress core files
wp core download

# create the wp-config file with our standard setup
wp core config --dbname=$dbname --dbuser=root --dbhost=127.0.0.1 --extra-php <<PHP
define('BASEURL', '$siteaddress');
define('CONTENT_DIR', 'app');

define('WP_CONTENT_DIR', dirname(__FILE__) . '/' . CONTENT_DIR);
define('WP_CONTENT_URL', BASEURL . '/' . CONTENT_DIR);
define('WP_PLUGIN_DIR',  dirname(__FILE__) . '/' . CONTENT_DIR . '/plugins');

define('WP_DEBUG', true);
define('DISALLOW_FILE_EDIT', true);

PHP

mv wp-config.php ..
cp index.php ..

# create database, and install WordPress
wp db create
wp core install --url="$siteaddress/wp" --title="$sitename" --admin_user="$wpuser" --admin_password="$wppass" --admin_email="$wpemail"

# show only 5 posts on an archive page
wp option update posts_per_page 5
wp option update home $siteaddress

# delete sample page, and create homepage
wp post delete $(wp post list --post_type=page --posts_per_page=1 --post_status=publish --pagename="sample-page" --field=ID --format=ids)
wp post delete $(wp post list --post_type=post --posts_per_page=1 --post_status=publish --postname="hello-world" --field=ID --format=ids)
wp post create --post_type=page --post_title=Home --post_status=publish --post_author=$(wp user get $wpuser --field=ID --format=ids)
wp post create --post_type=page --post_title=Blog --post_status=publish --post_author=$(wp user get $wpuser --field=ID --format=ids)

# set homepage as front page
wp option update show_on_front 'page'

# set homepage to be the new page
wp option update page_on_front $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=home --field=ID --format=ids)
wp option update page_for_posts $(wp post list --post_type=page --post_status=publish --posts_per_page=1 --pagename=blog --field=ID --format=ids)

# set timezone to central
wp option update timezone_string 'America/Chicago'

wp option update blogdescription ''
wp option update default_comment_status 'closed'
wp option update default_ping_status 'closed'
wp option update uploads_use_yearmonth_folders ''

# create all of the pages
export IFS=","
for page in $allpages; do
    wp post create --post_type=page --post_status=publish --post_author=$(wp user get $wpuser --field=ID --format=ids) --post_title="$(echo $page | sed -e 's/^ *//' -e 's/ *$//')"
done

# create all of the categories
export IFS=","
for category in $allcategories; do
    wp term create category $category
done

# set new category to default and remove 'Uncategorized'
wp option update default_category 2
wp option update default_email_category 2
wp term delete category 1

# set pretty urls
wp rewrite structure '/%postname%/' --hard
wp rewrite flush --hard

cd ..

tail -n 1 "index.php" | wc -c | xargs -I {} truncate "index.php" -s -{}
echo "require(dirname(__FILE__).'/wp/wp-blog-header.php');" >> index.php

echo "if ( empty( \$upload_path ) || 'wp-content/uploads' == \$upload_path ) {
    update_option( 'upload_path', untrailingslashit( str_replace( 'wp', 'app/media', ABSPATH ) ) );
    update_option( 'upload_url_path', home_url( 'app/media' ) );
}" >> wp-config.php

# install the company starter theme
# install the WordPress Boilerplate theme

cd app/themes
git clone https://github.com/Beth3346/wordpress-boilerplate-twig.git
cd wordpress-boilerplate-twig

composer install
npm install
grunt build

cd ..
cd ..
cd wp

wp theme activate wordpress-boilerplate-twig

## themes
# removes the inactive themes that automattically come wth an fresh installation of WP. Since WP needs one
# active theme, this command only removes the inactive one. -JMS
wp theme list --status=inactive --field=name | while read THEME; do wp theme delete $THEME; done;

clear

# create a navigation bar
wp menu create "Main Navigation"
wp menu create "Footer Navigation"
wp menu create "Social Navigation"

# remove most default widgets from sidebar
wp widget delete meta-2
wp widget delete search-2
wp widget delete recent-comments-2
wp widget delete archives-2

clear

echo "================================================================="
echo "Installation is complete. Your username/password is listed below."
echo ""
echo "Username: $wpuser"
echo "Password: $wppass"
echo ""
echo "================================================================="

fi