# Stage 1: Build the application using Maven inside Docker
FROM maven:3.8.4-openjdk-11-slim AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Stage 2: Create a secure, minimal runtime image
FROM eclipse-temurin:11-jre-alpine
WORKDIR /app
COPY --from=builder /app/target/basic*.jar /app/basic.jar
COPY src/main/resources/application.properties /opt/conf/application.properties

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/basic.jar", "--spring.config.location=file:/opt/conf/application.properties"]
