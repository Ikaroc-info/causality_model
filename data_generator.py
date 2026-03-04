import csv
import random
import math
import os

def generate_marketing_data():
    n = 500
    os.makedirs('test_data', exist_ok=True)
    with open('test_data/marketing_campaign.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['customer_id', 'age', 'past_spend', 'promo_email', 'revenue'])
        for i in range(n):
            age = random.randint(18, 70)
            past_spend = round(random.uniform(0, 1000), 2)
            
            # Probability of receiving email depends on past_spend
            prob_t = 1 / (1 + math.exp(-(past_spend - 500) / 100))
            treatment = 1 if random.random() < prob_t else 0
            
            # Revenue: Treatment has +50 effect
            revenue = 20 + 0.1 * past_spend + 50 * treatment + random.normalvariate(0, 10)
            writer.writerow([i, age, past_spend, treatment, round(revenue, 2)])

def generate_education_data():
    n = 300
    with open('test_data/education_study.csv', 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['student_id', 'prev_score', 'parent_years_edu', 'tutoring_session', 'final_exam_score'])
        for i in range(n):
            prev_score = random.randint(40, 90)
            parent_edu = random.randint(10, 20)
            
            # Tutoring more common for higher parent_edu
            prob_t = 1 / (1 + math.exp(-(parent_edu - 15) * 0.5))
            treatment = 1 if random.random() < prob_t else 0
            
            # Final score: Tutoring has +8 point effect
            test_score = 0.8 * prev_score + 1.2 * parent_edu + 8 * treatment + random.normalvariate(0, 5)
            test_score = max(0, min(100, test_score))
            writer.writerow([i, prev_score, parent_edu, treatment, round(test_score, 1)])

if __name__ == "__main__":
    generate_marketing_data()
    generate_education_data()
    print("Test CSV files generated in test_data/")
