import json
import os
import boto3
from datetime import datetime
from typing import Dict, Any
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import uuid
import uvicorn

app = FastAPI(title="High Scalable AWS Architecture API", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# AWS clients
dynamodb = boto3.resource('dynamodb')
eventbridge = boto3.client('events')
s3 = boto3.client('s3')

# Environment variables
TABLE_NAME = os.environ.get('TABLE_NAME', 'OrdersTable')
EVENT_BUS_NAME = os.environ.get('EVENT_BUS_NAME', 'default')
S3_BUCKET = os.environ.get('S3_BUCKET', '')

@app.get("/")
async def root():
    return {
        "message": "Welcome to High Scalable AWS Architecture API",
        "version": "1.0.0",
        "timestamp": datetime.utcnow().isoformat(),
        "environment": {
            "table_name": TABLE_NAME,
            "event_bus": EVENT_BUS_NAME,
            "s3_bucket": S3_BUCKET
        }
    }

@app.get("/health")
async def health_check():
    """Health check endpoint for load balancers"""
    try:
        # Test DynamoDB connection
        table = dynamodb.Table(TABLE_NAME)
        table.table_status
        
        return {
            "status": "healthy",
            "timestamp": datetime.utcnow().isoformat(),
            "services": {
                "dynamodb": "connected",
                "eventbridge": "available",
                "s3": "available"
            }
        }
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Service unhealthy: {str(e)}")

@app.post("/orders")
async def create_order(order: Dict[str, Any]):
    """Create a new order"""
    try:
        order_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat()
        
        # Save to DynamoDB
        table = dynamodb.Table(TABLE_NAME)
        item = {
            'pk': f"ORDER#{order_id}",
            'sk': f"METADATA#{timestamp}",
            'order_id': order_id,
            'status': 'created',
            'created_at': timestamp,
            **order
        }
        
        table.put_item(Item=item)
        
        # Send event to EventBridge
        event_detail = {
            'order_id': order_id,
            'status': 'created',
            'timestamp': timestamp
        }
        
        eventbridge.put_events(
            Entries=[
                {
                    'Source': 'myapp.orders',
                    'DetailType': 'Order Created',
                    'Detail': json.dumps(event_detail),
                    'EventBusName': EVENT_BUS_NAME
                }
            ]
        )
        
        return {
            "order_id": order_id,
            "status": "created",
            "timestamp": timestamp
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create order: {str(e)}")

@app.get("/orders/{order_id}")
async def get_order(order_id: str):
    """Get an order by ID"""
    try:
        table = dynamodb.Table(TABLE_NAME)
        response = table.query(
            KeyConditionExpression='pk = :pk',
            ExpressionAttributeValues={
                ':pk': f"ORDER#{order_id}"
            }
        )
        
        if not response['Items']:
            raise HTTPException(status_code=404, detail="Order not found")
        
        return response['Items'][0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to get order: {str(e)}")

@app.put("/orders/{order_id}/status")
async def update_order_status(order_id: str, status_data: Dict[str, str]):
    """Update order status"""
    try:
        new_status = status_data.get('status')
        if not new_status:
            raise HTTPException(status_code=400, detail="Status is required")
        
        timestamp = datetime.utcnow().isoformat()
        table = dynamodb.Table(TABLE_NAME)
        
        # Update the order status
        table.update_item(
            Key={
                'pk': f"ORDER#{order_id}",
                'sk': f"METADATA#{timestamp}"
            },
            UpdateExpression='SET #status = :status, updated_at = :timestamp',
            ExpressionAttributeNames={'#status': 'status'},
            ExpressionAttributeValues={
                ':status': new_status,
                ':timestamp': timestamp
            }
        )
        
        # Send status update event
        event_detail = {
            'order_id': order_id,
            'status': new_status,
            'timestamp': timestamp
        }
        
        eventbridge.put_events(
            Entries=[
                {
                    'Source': 'myapp.orders',
                    'DetailType': 'Order Status Updated',
                    'Detail': json.dumps(event_detail),
                    'EventBusName': EVENT_BUS_NAME
                }
            ]
        )
        
        return {
            "order_id": order_id,
            "status": new_status,
            "timestamp": timestamp
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update order: {str(e)}")

@app.get("/orders")
async def list_orders():
    """List all orders"""
    try:
        table = dynamodb.Table(TABLE_NAME)
        response = table.scan()
        
        return {
            "orders": response['Items'],
            "count": response['Count']
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list orders: {str(e)}")

@app.post("/files/upload")
async def upload_file(file_data: Dict[str, Any]):
    """Upload a file to S3 (demo endpoint)"""
    try:
        if not S3_BUCKET:
            raise HTTPException(status_code=500, detail="S3 bucket not configured")
        
        file_key = f"uploads/{uuid.uuid4()}-{file_data.get('filename', 'file')}"
        
        # In a real implementation, you'd handle actual file upload
        # This is just a demo that shows S3 integration
        s3.put_object(
            Bucket=S3_BUCKET,
            Key=file_key,
            Body=json.dumps(file_data).encode('utf-8'),
            ContentType='application/json'
        )
        
        return {
            "file_key": file_key,
            "bucket": S3_BUCKET,
            "timestamp": datetime.utcnow().isoformat()
        }
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to upload file: {str(e)}")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 