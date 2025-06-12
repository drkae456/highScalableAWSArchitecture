FROM public.ecr.aws/lambda/python:3.11

# Copy requirements first for better caching
COPY app/requirements.txt ${LAMBDA_TASK_ROOT}/

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app/ ${LAMBDA_TASK_ROOT}/

# Set the CMD to your handler
CMD ["main.handler"] 