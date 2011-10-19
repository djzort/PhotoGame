#/bin/sh
mysqldump photo_game -u root -p -c | sed 's/AUTO_INCREMENT=[0-9][0-9]* //' - > photo_game.sql
