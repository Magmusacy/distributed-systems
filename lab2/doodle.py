from fastapi import FastAPI, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel


polls = []
votes = []

app = FastAPI()

class Poll(BaseModel):
    id: int = None
    creator_id: int
    title: str
    description: str
    options: list[str]

class VoteCreate(BaseModel):
    vote_id: int
    voter_id: int
    option: str

class Vote(BaseModel):
    vote_id: int = None
    poll_id: int = None
    voter_id: int
    option: str

@app.post("/poll/")
async def create_poll(poll: Poll):
    polls.append(poll)
    return poll

@app.post("/vote/{poll_id}")
async def create_vote(poll_id: int, vote_create: VoteCreate):
    poll = next((p for p in polls if p.id == poll_id), None)
    if poll is None:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"message": "Poll not found"})
    if vote_create.option not in poll.options:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"message": "Invalid option"})
    vote = Vote(vote_id=vote_create.vote_id, poll_id=poll_id, voter_id=vote_create.voter_id, option=vote_create.option)
    votes.append(vote)
    return JSONResponse(status_code=status.HTTP_201_CREATED, content=vote.model_dump())

@app.put("/vote/{vote_id}")
async def change_vote(vote_id: int, vote: Vote):
    existing = next((v for v in votes if v.vote_id == vote_id), None)
    if existing is None:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"message": "Vote not found"})
    poll = next((p for p in polls if p.id == existing.poll_id), None)
    if poll is None:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"message": "Poll not found"})
    if vote.option not in poll.options:
        return JSONResponse(status_code=status.HTTP_400_BAD_REQUEST, content={"message": "Invalid option"})
    existing.option = vote.option
    return JSONResponse(status_code=status.HTTP_200_OK, content=existing.model_dump())

@app.delete("/vote/{vote_id}")
async def delete_vote(vote_id: int, voter_id: int):
    for v in votes:
        if v.vote_id == vote_id and v.voter_id == voter_id:
            votes.remove(v)
            return JSONResponse(status_code=status.HTTP_200_OK, content={"message": "Vote deleted"})
    return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"message": "Vote not found"})

@app.get("/poll/{poll_id}/results")
async def get_results(poll_id: int):
    poll = next((p for p in polls if p.id == poll_id), None)
    if poll is None:
        return JSONResponse(status_code=status.HTTP_404_NOT_FOUND, content={"message": "Poll not found"})
    results = {}
    for v in votes:
        if v.poll_id == poll_id:
            results[v.option] = results.get(v.option, 0) + 1
    return JSONResponse(status_code=status.HTTP_200_OK, content=results)

@app.get("/polls/")
async def get_polls():
    return polls