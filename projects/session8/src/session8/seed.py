import uuid

from dotenv import load_dotenv
from faker import Faker

from session8.connection import get_engine, get_inputs_connstr, get_insights_connstr
from session8.db_utils import create_new_participant, create_new_task
from session8.models import inputs, insights

load_dotenv()
faker = Faker()

if __name__ == "__main__":
    # Example usage
    inputs_engine = get_engine(get_inputs_connstr())

    inputs.Base.metadata.create_all(inputs_engine)

    insights_engine = get_engine(get_insights_connstr())

    insights.Base.metadata.create_all(insights_engine)

    tasks = 2
    participants = 150 

    for task_id in range(1, tasks + 1):
        new_task_id = uuid.uuid4()
        create_new_task(engine=inputs_engine, task_id=new_task_id)
        for participant_id in range(1, participants + 1):
            create_new_participant(engine=inputs_engine, task_id=new_task_id, participant_id=uuid.uuid4())

    inputs_engine.dispose()
    insights_engine.dispose()


