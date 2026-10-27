FROM oraclelinux:7
COPY out/rpms-stock/ /tmp/rpms/
RUN yum -y install httpd \
 && yum -y localinstall /tmp/rpms/php56w-5.6.40-1.w7.x86_64.rpm /tmp/rpms/php56w-cli-5.6.40-1.w7.x86_64.rpm /tmp/rpms/php56w-common-5.6.40-1.w7.x86_64.rpm \
 && yum clean all && rm -rf /tmp/rpms
COPY tests/php-test.ini /etc/php.d/zz-test.ini
COPY tests/web/ /var/www/html/test/
CMD ["/usr/sbin/httpd", "-DFOREGROUND"]
