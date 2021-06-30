# Provisioning script for the discovery service
./provision-ida.sh discovery discovery 18381

docker-compose exec -T discovery bash -c 'rm -rf /edx/var/discovery/*'
docker-compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py create_or_update_partner --site-id 1 --site-domain localhost:18381 --code edx --name edX --courses-api-url "http://edx.devstack.lms:18000/api/courses/v1/" --ecommerce-api-url "http://edx.devstack.ecommerce:18130/api/v2/" --organizations-api-url "http://edx.devstack.lms:18000/api/organizations/v0/" --lms-url "http://edx.devstack.lms:18000/"'
docker-compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py create_or_update_partner --site-id 2 --site-domain discovery.pearson.localhost:18381 --code PX --name PearsonX --courses-api-url "http://lms.pearson.localhost:18000/api/courses/v1/" --ecommerce-api-url "http://ecommerce.pearson.localhost:18130/api/v2/" --organizations-api-url "http://lms.pearson.localhost:18000/api/organizations/v0/" --lms-url "http://lms.pearson.localhost:18000/"'
docker-compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py create_or_update_partner --site-id 3 --site-domain discovery.main.localhost:18381 --code main --name main --courses-api-url "http://lms.main.localhost:18000/api/courses/v1/" --ecommerce-api-url "http://ecommerce.main.localhost:18130/api/v2/" --organizations-api-url "http://lms.main.localhost:18000/api/organizations/v0/" --lms-url "http://lms.main.localhost:18000/"'
docker-compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py refresh_course_metadata'
docker-compose exec -T discovery bash -c 'source /edx/app/discovery/discovery_env && python /edx/app/discovery/discovery/manage.py update_index --disable-change-limit'

# Add demo program
./programs/provision.sh discovery
