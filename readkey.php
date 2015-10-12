<?php
if ($argc < 2) {
	print "Usage: ".$argv[0]." <pubkey>\n";
	die();
}

if ($pub_key = openssl_pkey_get_public(file_get_contents($argv[1]))) {
	$keyData = openssl_pkey_get_details($pub_key);
	print "Key data:\n".var_export($keyData, true);
} else {
	print "Error reading key from ".$argv[1]."\n";
}
?>
