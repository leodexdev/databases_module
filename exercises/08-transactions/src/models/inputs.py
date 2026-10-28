from sqlalchemy import Column, Data, Integer, String, Float, ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base

Base = declarative_base()

class Task(PublicBase):
    __tablename__ = 'tasks'

    id = Column(UUID, primary_key=True)
    name = Column(String, nullable=False)
    description = Column(String, nullable=False)
    started_at = Column(String, nullable=False)
    finished_at = Column(String, nullable=False)
    status = Column(String, nullable=False)
    outcome = Column(String, nullable=False)

class Participant(PublicBase)
    __tablename__ = 'participants'

    id = Column(UUID, primary_key=True)
    name = Column(String, nullable=False)
    surname = Column(String, nullable=False)
    height = Column(Float, nullable=False)
    weight = Column(Float, nullable=False)
    city = Column(String, nullable=False)
    date_of_birth = Column(Data, nullable=False)
    heart_rate = Column(Integer, nullable=False)
    blood_pressure_systolic = Column(Integer, nullable=False)
    blood_pressure_diastolic = Column(Integer, nullable=False)
    task_id = Column(UUID,ForeignKey('tasks.id'), nullable=False)
