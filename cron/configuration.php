<?php
if(!defined('HOMER_CONFIGURATION')):
define('HOMER_CONFIGURATION', 1);
/*********************************************************************************/
/* AUTH DB homer. User and Configuration */
define('DB_HOSTNAME', "{{ DB_HOST }}");
define('DB_PORT', 3306);
define('DB_USERNAME', "{{ DB_USER }}");
define('DB_PASSWORD', "{{ DB_PASS }}");
define('DB_CONFIGURATION', "homer_configuration");
define('DB_STATISTIC', "homer_statistic");
define('DB_HOMER', "homer_data");
define('SINGLE_NODE', 1);
/*********************************************************************************/
/* webHomer Settings 
*  Adjust to reflect your system preferences
*/
define('PCAPDIR', ROOT."/tmp/");
define('WEBPCAPLOC',"/tmp/");
/* INCLUDE preferences */
include_once("preferences.php");
endif;
?>
