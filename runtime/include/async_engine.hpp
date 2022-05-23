#pragma once

#include "value.hpp"
#include <deque>

namespace axon {
namespace runtime {

class AsyncTask {
public:
    virtual ~AsyncTask() = default;
    virtual bool isDone() const = 0;
    virtual ValuePtr getResult() const = 0;
    virtual void step() = 0;
};

using AsyncTaskPtr = std::shared_ptr<AsyncTask>;

class AsyncScheduler {
private:
    std::deque<AsyncTaskPtr> task_queue_;

public:
    void enqueue(AsyncTaskPtr task) {
        task_queue_.push_back(std::move(task));
    }

    void runAll() {
        while (!task_queue_.empty()) {
            auto task = task_queue_.front();
            task_queue_.pop_front();
            task->step();
            if (!task->isDone()) {
                task_queue_.push_back(task);
            }
        }
    }

    size_t pendingCount() const {
        return task_queue_.size();
    }
};

} // namespace runtime
} // namespace axon
