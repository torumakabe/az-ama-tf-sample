#!/bin/bash

echo 'test' > /tmp/test.txt

cat - << EOT > /tmp/check_file.sh
#!/bin/bash
while true
do
    if [[ ! -e /tmp/test.txt ]]; then
    logger -p user.err "[ERROR_SAMPLE] /tmp/test.txt not found."
    fi
    sleep 60
done
EOT

chmod +x /tmp/check_file.sh
/tmp/check_file.sh &
