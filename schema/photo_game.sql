-- MySQL dump 10.13  Distrib 5.1.58, for debian-linux-gnu (x86_64)
--
-- Host: localhost    Database: photo_game
-- ------------------------------------------------------
-- Server version	5.1.58-1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `messages`
--

DROP TABLE IF EXISTS `messages`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `messages` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `photographer_id` int(10) unsigned NOT NULL COMMENT 'Photographer who this message is for',
  `content` text NOT NULL COMMENT 'Actual message',
  PRIMARY KEY (`id`),
  KEY `fk_photographer_id_3` (`photographer_id`),
  CONSTRAINT `fk_photographer_id_3` FOREIGN KEY (`photographer_id`) REFERENCES `photographers` (`photographer_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Messages for photographers';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `messages`
--

LOCK TABLES `messages` WRITE;
/*!40000 ALTER TABLE `messages` DISABLE KEYS */;
/*!40000 ALTER TABLE `messages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `photographers`
--

DROP TABLE IF EXISTS `photographers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `photographers` (
  `photographer_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `full_name` varchar(255) NOT NULL COMMENT 'Full name',
  `email_addr` varchar(255) NOT NULL COMMENT 'Email address',
  `username` varchar(255) NOT NULL COMMENT 'Username',
  `password` varchar(255) NOT NULL COMMENT 'Password',
  `creation_ip` varchar(255) NOT NULL COMMENT 'IP address at creation of user',
  `avatar` varchar(255) NOT NULL COMMENT 'Avatar for the user',
  PRIMARY KEY (`photographer_id`),
  KEY `username_idx` (`username`,`password`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='People participating in the game';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `queue`
--

DROP TABLE IF EXISTS `queue`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `queue` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `orig_name` varchar(255) NOT NULL COMMENT 'Original name of file',
  `file_name` varchar(255) NOT NULL COMMENT 'Name of file in filesystem',
  `photographer_id` int(10) unsigned NOT NULL COMMENT 'Photographer who took the photo',
  PRIMARY KEY (`id`),
  KEY `fk_photographer_id_2` (`photographer_id`),
  CONSTRAINT `fk_photographer_id_2` FOREIGN KEY (`photographer_id`) REFERENCES `photographers` (`photographer_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='Queue of incoming specimens';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `settings`
--

DROP TABLE IF EXISTS `settings`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `settings` (
  `key` varchar(255) NOT NULL COMMENT 'Key',
  `value` varchar(255) NOT NULL COMMENT 'Value',
  PRIMARY KEY (`key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1 COMMENT='Various settings';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `settings`
--

LOCK TABLES `settings` WRITE;
/*!40000 ALTER TABLE `settings` DISABLE KEYS */;
INSERT INTO `settings` (`key`, `value`) VALUES ('registration_open','1'),('submissions_open','1'),('voting_open','1'),('max_submissions','10'),('results_open','1'),('use_gravatars','1');
/*!40000 ALTER TABLE `settings` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `specimens`
--

DROP TABLE IF EXISTS `specimens`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `specimens` (
  `specimen_id` int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'ID',
  `file_name` varchar(255) NOT NULL COMMENT 'Filename of the photo',
  `photographer_id` int(10) unsigned NOT NULL COMMENT 'Person who took the photo',
  `orig_name` varchar(255) NOT NULL COMMENT 'Original file name',
  `orig_md5` varchar(255) NOT NULL COMMENT 'Original file MD5',
  PRIMARY KEY (`specimen_id`) USING BTREE,
  KEY `k_orig_md5` (`orig_md5`),
  KEY `fk_photographer_id` (`photographer_id`),
  CONSTRAINT `fk_photographer_id` FOREIGN KEY (`photographer_id`) REFERENCES `photographers` (`photographer_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='photos taken';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `votes`
--

DROP TABLE IF EXISTS `votes`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `votes` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `winner` int(10) unsigned NOT NULL COMMENT 'Winning Vote',
  `loser` int(10) unsigned NOT NULL COMMENT 'Losing Vote',
  `ip_address` varchar(255) NOT NULL COMMENT 'Ip Address of voter',
  PRIMARY KEY (`id`),
  KEY `fk_loser` (`loser`),
  KEY `winner_loser_idx` (`winner`,`loser`),
  CONSTRAINT `fk_loser` FOREIGN KEY (`loser`) REFERENCES `specimens` (`specimen_id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `fk_winner` FOREIGN KEY (`winner`) REFERENCES `specimens` (`specimen_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COMMENT='votes for specimens';
/*!40101 SET character_set_client = @saved_cs_client */;

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2011-10-29 16:40:26
