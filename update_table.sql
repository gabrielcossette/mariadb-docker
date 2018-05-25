-- phpMyAdmin SQL Dump
-- version 4.7.7
-- https://www.phpmyadmin.net/
--
-- Host: db
-- Generation Time: Feb 11, 2018 at 02:27 AM
-- Server version: 10.2.12-MariaDB-10.2.12+maria~jessie
-- PHP Version: 7.1.9

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

USE phpmyadmin;

UPDATE `pma__userconfig` SET password='{\"Console\\/Mode\":\"collapse\",\"2fa\":{\"backend\":\"application\",\"settings\":{\"secret\":\"SECRETUSER1\"}}}' WHERE login='username1';
UPDATE `pma__userconfig` SET password='{\"Console\\/Mode\":\"collapse\",\"2fa\":{\"backend\":\"application\",\"settings\":{\"secret\":\"SECRETUSER2\"}}}' WHERE login='username2';
UPDATE `pma__userconfig` SET password='{\"Console\\/Mode\":\"collapse\",\"2fa\":{\"backend\":\"application\",\"settings\":{\"secret\":\"SECRETUSER3\"}}}' WHERE login='username3';

FLUSH PRIVILEGES;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
