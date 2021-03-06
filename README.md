Welcome to PhotoGame!
=====================

This is a simple game for LANparty's, in the form of a web application written in [Perl](http://learn.perl.org) using the [Catalyst MVC framework](http://www.catalystframework.org).

Synopsis
--------

PhotoGame is a fun way to make a competition out of taking photos during your LANparty! Guests register and submit the photos they take, whilst other guests vote on the photos to decide the winner, then all you have to do is give out the prizes!

So with one simple application, we've found an easy way of encouraging our guests to take great photos then to hand them over - and given all our guests the chance to be part of the judging (ie made it social) by allowing other guests to do the judging for us!

Installation
------------

PhotoGame is a simple Catalyst application, please refer to the Catalyst MVC documentation for exhaustive details.

Configuration and Templates
---------------------------

The file `photogame.conf` in the top most directory contains the application configuration, including database details and the two paths: the queue path and the upload path that is exposed out via your webserver. Note: changing the upload path will require you to make minor template changes. The format of this file is 'apache like', though not recommended it can easily be changed to xml, yaml, perl, ini or a variety of formats as per Catalyst. You just need to change the filename suffix and the file contents to the appropriate content - Catalyst will work out the rest.

You can find the customisable templates in `root/*tt` - these are Template Toolkit style templates. The input forms are (except the voting form) generated by HTML::FormFu using templates in `root/forms/*yml`, changing them isnt recommended either.

The provided templates are very basic, I would gladly welcome contributions with more eye candy.

Application Server
------------------

Catalyst uses Plack to provide its application server interface, which will allow you to run this application using mod_perl, fastcgi, psgi or as a standalone system (not recommended). Allowing you to choose your favourite webserver - be that apache, nginx, lighttpd or other. Perhaps you could even run it in a public PAAS cloud.

Install your favourite webserver that supports one of the above, and refer to the Catalyst MVC documentation for how to make a connection.

Database
--------

The only database currently supported is MySQL (I know I know, I should have used PostgreSQL). As I've not used an ORM with the model (mainly because I dont like them), using a different database will require a little work in adapting the SQL statements. Please fork and create one if you like, I will happily merge it.

You will find the MySQL schema in `schema/photo_game.sql`. Create a new mysql database, and use the SQL to create the tables and their relationships (You will need InnoDB support as I make extensive use of foreign keys).

Queue Worker
------------

Photos aren't processed when submitted, they are queued (just in a queue table, with a temporary holding directory) then processed by a worker.

This worker is `script/photogame_queue.pl`, it doesn't collect its settings from the photogame.conf file (yet) but has them at the top of the file. You will therefore need to edit the file to set the database and image parameters.

For now, the worker runs then exits. So use might use cron to run it every minute, or when developing you can run it over and over using the 'watch' command with an appropriate interval.

I would like to have this run via Gearman eventually.

Stand Alone Server
------------------

Just run `script/photogame_server.pl` to test the application. Then point your favourite browser at `http://localhost:3000`

Admin Functions
---------------

There are currently no admin functions. If you wish to delete photos, just remove the respective row in the `specimens` table, the foreign key relationships will remove the relevant votes. Or delete the photographer from the `photographers` table and foreign key relationships will remove his/her photos and the votes for the specimen. In both cases, the files themselves will still remain.

FragFest
--------

Please check out our LANparty at http://fragfest.com.au

License
-------

This library is free software. You can redistribute it and/or modify it under the same terms as Perl itself.
