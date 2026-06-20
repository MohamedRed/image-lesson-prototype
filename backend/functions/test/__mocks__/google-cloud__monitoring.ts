export class MetricServiceClient {
  projectPath(projectId: string) { return `projects/${projectId||'demo-project'}`; }
  createTimeSeries() { return Promise.resolve(); }
}
export default { MetricServiceClient } as any;









