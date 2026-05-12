cd /var/www/website/Riders-communities/website
bash

git pull
bash

npm install
bash

npm run build
bash

pm2 restart ride-with-garv
Bas. Nginx ko usually touch nahi karna.

Agar package change nahi hua, tab bhi npm install chalana safe hai. Fast hota hai agar kuch update nahi hua.

Check karne ke liye:

bash

pm2 status
bash

curl -I http://127.0.0.1:3001
Aur agar server reboot ke baad auto start chahiye, ek baar ye ensure karna:

bash

pm2 save
bash

pm2 startup
