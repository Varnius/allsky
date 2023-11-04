<?php
	$configFilePrefix = "../";
	include_once('functions.php'); disableBuffering();	 // must be first line
	// Settings are now in $website_settings_array.

	if (! isset($dir) || ! isset($prefix) || ! isset($title)) {
		echo "<p>INTERNAL ERROR: incomplete arguments given to view thumbnails.</p>";
		echo "dir, prefix, and/or title missing.";
		exit;
	}
	$homePage = v("homePage", null, $website_settings_array);
	$includeGoogleAnalytics = v("includeGoogleAnalyticsx", false, $homePage);
	$favicon = v("favicon", "allsky-favicon.png", $homePage);
	$ext = pathinfo($favicon, PATHINFO_EXTENSION); if ($ext === "jpg") $ext = "jpeg";
	$faviconType = "image/$ext";

?>
<!DOCTYPE html>
<html lang="en">
	<head>
		<meta http-equiv="Content-Type" content="text/html" />
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<link rel="shortcut icon" type="<?php echo $faviconType ?>" href="<?php echo "../$favicon" ?>">
		<title><?php echo $title; ?></title>

		<script src="https://ajax.googleapis.com/ajax/libs/jquery/3.6.0/jquery.min.js"></script>
<?php	if ($includeGoogleAnalytics && file_exists("../analyticsTracking.js")) {
			echo "<script src='../analyticsTracking.js'></script>";
		}
?>
		<script defer src="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/5.15.4/js/all.min.js"></script>
		<link href="../allsky.css" rel="stylesheet">
	</head>
	<body>
		<?php display_thumbnails($dir, $prefix, $title); ?>
	</body>
</html>
