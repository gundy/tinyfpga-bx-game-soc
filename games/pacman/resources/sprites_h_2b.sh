#/usr/bin/env sh

if [ $# -eq 0 ] || [ "$1" == "-h" ] ; then
    echo "Usage: `basename $0` [-h] <prites.h>"
    exit 0
fi

cat $1 \
	| sed -n '/^static char header_data\[/,/\}\;/p'  	`# extract lines that contain texture data ` \
	| grep '[0-9]' 						`# strip out the array header and prologue` \
	| sed -e 's/^[ \t]*//' 					`# remove trailing space ` \
	| tr '\n' ' '						`# remove newlines ` \
	| sed -e 's/ //g'					`# remove spaces between numbers ` \
	| awk -F "," '{ for(i=1; i<=NF; i++) {if ((i-1)%16==0) printf("        "); if ((i-1)%256==0) printf("{"); if ((i-1)%16==0) printf("0b"); printf("%1x",$i); if ((i-1)%16==15) {if ((i-1)%256==255) printf("},"); else printf(","); printf("\n"); }}; printf("\n"); }' 


