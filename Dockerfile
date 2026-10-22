FROM nginx:alpine
# Intentionally missing the COPY statement to trigger a deployment rollout failure
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
