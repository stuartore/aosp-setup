app_list=(
./bin/system/product/priv-app/com.huawei.android.hsf/com.huawei.android.hsf.apk
./bin/system/product/priv-app/HMSCore/HMSCore.apk
./bin/system/product/priv-app/Appdiscovery/Appdiscovery.apk
./bin/system/product/priv-app/com.huawei.android.pushagent/com.huawei.android.pushagent.apk
)

file=priv.xml
echo '<?xml version="1.0" encoding="utf-8"?>' > $file
echo '<permissions>' >> $file

for app in "${app_list[@]}"
do
	app_pkg_name="$(aapt d permissions $app | grep 'package:' | sed 's|package: ||g')"
	app_perm_list=($(aapt d permissions ./bin/system/product/priv-app/HMSCore/HMSCore.apk | grep "'android.permission." | sed 's|uses-permission: name=||g' | sed "s/'//g"))
	echo "<privapp-permissions package=\"$app_pkg_name\">" >> $file
	for app_perm in "${app_perm_list[@]}"
	do
		echo "    <permission name=\"$app_perm\" />" >> $file
	done
	echo '</privapp-permissions>' >> $file
	echo >> $file
done

echo '</permissions>' >> $file
