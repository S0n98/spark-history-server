FROM apache/spark:3.5.1

USER root

RUN wget -q -O /opt/spark/jars/hadoop-aws-3.3.4.jar \
      https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.4/hadoop-aws-3.3.4.jar && \
    wget -q -O /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar \
      https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.12.262/aws-java-sdk-bundle-1.12.262.jar && \
    chmod 644 /opt/spark/jars/hadoop-aws-3.3.4.jar \
              /opt/spark/jars/aws-java-sdk-bundle-1.12.262.jar

USER spark
