# BASE
FROM alpine

# Install Nginx and create necessary directories
RUN apk add --no-cache nginx \
    #&& mkdir /run/nginx/ \
    && mkdir -p /var/www/localhost/htdocs

# Install curl for testing
RUN apk add --no-cache curl

# Install OpenSSL
RUN apk add --no-cache openssl

# Create a self-signed certificate and key
RUN openssl req -x509 -nodes -days 365 -subj "/C=FR/ST=Drôme/O=ESGI, Inc./CN=guigui.com" -addext "subjectAltName=DNS:guiugi.com" -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

# Configure Nginx
COPY default.conf /etc/nginx/conf.d/default.conf

# Create an HTML file
RUN echo "<h1>Hello world!</h1> <p>Rajoutez votre gif par exemple</p>" > /var/www/localhost/htdocs/index.html

# Expose ports
EXPOSE 80
EXPOSE 443

# CMD to start Nginx
CMD ["nginx", "-g", "daemon off;"]
