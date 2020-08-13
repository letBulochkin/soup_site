ENDPOINT="https://storage.cloud.croc.ru"
BUCKET_NAME="lab02-website"
BUCKET_URL="s3://$BUCKET_NAME/"
SITE_PATH="public/"

#echo $ENDPOINT
#echo $BUCKET_URL
hugo
aws s3 rm $BUCKET_URL  --recursive --endpoint-url=$ENDPOINT
aws s3 cp $SITE_PATH $BUCKET_URL --recursive --endpoint-url=$ENDPOINT
aws s3 ls $BUCKET_URL --recursive --endpoint-url=$ENDPOINT | while read line ; 
do 
	set $line ;
       	echo "Setting public read permission for object $4 ..."	
	aws s3api put-object-acl --bucket $BUCKET_NAME --key $4 --acl public-read --endpoint-url=$ENDPOINT ; 
done
