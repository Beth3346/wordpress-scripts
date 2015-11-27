# install required plugins

#!/bin/bash -e

clear

echo "================================================================="
echo "Beth's Awesome WordPress Installer!!"
echo "================================================================="

# accept user input for the user name
echo "Username: "
read -e wpuser

# accept user input for the user email
echo "Admin Email: "
read -e wpemail

# accept user input for the databse name
echo "Database Name: "
read -e dbname

# accept the name of our website
echo "Site Name: "
read -e sitename

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

# download the WordPress core files
wp core download

# create the wp-config file with our standard setup
wp core config --dbname=$dbname --dbuser=root --dbhost=127.0.0.1 --extra-php <<PHP
define( 'WP_DEBUG', true );
PHP

# parse the current directory name
currentdirectory=${PWD##*/}

# generate random 12 character password
password='admin'

# create database, and install WordPress
wp db create
wp core install --url="http://localhost:8000" --title="$sitename" --admin_user="$wpuser" --admin_password="$password" --admin_email="$wpemail"

# show only 5 posts on an archive page
wp option update posts_per_page 5

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

# delete akismet and hello dolly
wp plugin delete akismet
wp plugin delete hello

wp plugin install all-in-one-seo-pack
wp plugin install disable-comments
wp plugin install duplicate-post
wp plugin install html-sitemap
wp plugin install post-types-order
wp plugin install regenerate-thumbnails
wp plugin install wp-smushit
wp plugin install lazy-load

wp plugin activate --all

# install the company starter theme
# install the WordPress Boilerplate theme
cd wp-content/themes/
git clone https://github.com/elr-wordpress/wordpress-boilerplate
mv {wordpress-boilerplate/*,wordpress-boilerplate/.*} .
rm -rf wordpress-boilerplate
npm install && grunt build

wp theme activate wordpress-boilerplate

## themes
# removes the inactive themes that automattically come wth an fresh installation of WP. Since WP needs one
# active theme, this command only removes the inactive one. -JMS
wp theme list --status=inactive --field=name | while read THEME; do wp theme delete $THEME; done;

clear

# create a navigation bar
wp menu create "Main Navigation"

# add pages to navigation
export IFS=" "
for pageid in $(wp post list --order="ASC" --orderby="date" --post_type=page --post_status=publish --posts_per_page=-1 --field=ID --format=ids); do
    wp menu item add-post main-navigation $pageid
done

# assign navigaiton to primary location
wp menu location assign main-navigation primary

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
echo "Password: $password"
echo ""
echo "================================================================="

# Open the new website with Google Chrome
php -S localhost:8000
/usr/bin/open -a "/Applications/Google Chrome.app" "http://localhost:8000/"

fi