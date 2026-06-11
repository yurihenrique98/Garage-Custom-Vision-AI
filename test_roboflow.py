from inference_sdk import InferenceHTTPClient

client = InferenceHTTPClient(
    api_url="https://serverless.roboflow.com",
    api_key="3Ll2h0sWiRJ7TjfBuDoP"
)

result = client.run_workflow(
    workspace_name="yuris-workspace-t8bqo",
   workflow_id="custom-workflow",
    images={
        "image": "test_car.png"
    },
    use_cache=True
)

print(result)