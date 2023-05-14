using UnityEngine;
using System.Collections.Generic;

namespace Game
{
    public static class ComputeMeshHelper
    {
        private static MeshCompute mMeshCompute;

        public static void GenerateScetorOutLineByGround(ref List<Vector3> vertices, Transform sectorTransform,
            float angle, float radius, int number, LayerMask mask, LayerMask maskDown) =>
            (mMeshCompute ??= new MeshCompute()).GenerateScetorOutLineByGround(ref vertices, sectorTransform, angle,
                radius, number, mask, maskDown);

        public static void GenerateSectorDecalByGround(ref List<Vector3> vertices, ref List<int> indices,
            ref List<Vector2> uv, Transform sectorTransform,
            float angle, float radius, int number, LayerMask mask) =>
            (mMeshCompute ??= new MeshCompute()).GenerateSectorDecalByGround(ref vertices, ref indices, ref uv,
                sectorTransform, angle, radius, number, mask);
    }

    class MeshCompute
    {
        private RaycastHit[] hit = new RaycastHit[1];

        public void GenerateScetorOutLineByGround(ref List<Vector3> vertices, Transform sectorTransform, float angle,
            float radius, int number, LayerMask mask, LayerMask maskDown)
        {
            hit = new RaycastHit[1]; 
            angle *= Mathf.Deg2Rad;
            var yOffset = Vector3.up * 0.03f;
            var angleLength = angle / number;
            var numbers = 0;
            var position = sectorTransform.position + yOffset;
            vertices.Add(position);
            var x = radius * Mathf.Sin(-angle / 2f);
            var z = radius * Mathf.Cos(-angle / 2f);
            var sectorPoint = sectorTransform.TransformPoint(new Vector3(x, 0, z));
            var endPoint = Vector3.zero;
            Ray ray;
            ray = new Ray(position, sectorPoint - position);
            if (Physics.RaycastNonAlloc(ray, hit, radius, mask) > 0)
            {
                sectorPoint = new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z);
            }

            //第一阶段
            for (float i = 0; i < radius; i += 0.1f * radius)
            {
                float precent = i / radius;
                Vector3 targetPos = (sectorPoint - position) * precent + position;
                targetPos.y += 2f;
                ray = new Ray(targetPos, Vector3.down);
                if (Physics.RaycastNonAlloc(ray, hit, radius * 2f, maskDown) > 0)
                {
                    endPoint = new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z);
                }
                else
                {
                    endPoint = targetPos;
                }

                vertices.Add(endPoint);
                yOffset = new Vector3(0, endPoint.y + 0.003f, 0f);
            }

            position.y = yOffset.y;
            //第二阶段
            for (var i = -angle / 2f; i <= angle / 2f; i += angleLength)
            {
                x = radius * Mathf.Sin(i);
                z = radius * Mathf.Cos(i);
                sectorPoint = sectorTransform.TransformPoint(new Vector3(x, 0, z));
                sectorPoint.y = yOffset.y;
                ray = new Ray(position, sectorPoint - position);
                if (Physics.RaycastNonAlloc(ray, hit, radius, mask) > 0)
                {
                    endPoint = new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z);
                }
                else
                {
                    endPoint = sectorPoint;
                }
                ray = new Ray(endPoint, Vector3.down);
                if (Physics.RaycastNonAlloc(ray, hit, radius, maskDown) > 0)
                {
                    endPoint = new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z);
                }
                vertices.Add(endPoint);
                numbers++;
            }

            //第三阶段
            for (float i = radius; i > 0f; i -= 0.1f * radius)
            {
                float precent = i / radius;
                Vector3 targetPos = (sectorPoint - position) * precent + position;
                ray = new Ray(targetPos, Vector3.down);
                if (Physics.RaycastNonAlloc(ray, hit, radius, maskDown) > 0)
                {
                    endPoint = new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z);
                }
                else
                {
                    endPoint = targetPos;
                }

                vertices.Add(endPoint);
            }

            vertices.Add(position);
        }

        /// <summary>
        /// 通过一些数据生成一个扇形立体的decal，条件详见输入值
        /// 通过一个片向上缝成一个扇形，其实不需要缝顶端，正面剔除了就行了
        /// 所以先把点找出来，在点中间插入两个三角片，水平位置是这个三角片的中间位置即可
        /// 
        /// </summary>
        /// <param name="vertices"></param>
        /// <param name="indices"></param>
        /// <param name="uv"></param>
        /// <param name="angle"></param>
        /// <param name="radius"></param>
        /// <param name="number"></param>
        public void GenerateSectorDecalByGround(ref List<Vector3> vertices, ref List<int> indices, ref List<Vector2> uv,
            Transform sectorTransform,
            float angle, float radius, int number, LayerMask mask)
        {
            angle *= Mathf.Deg2Rad;

            var position = sectorTransform.localPosition;
            var angleLength = angle / number;
            //构建第一部分侧面decal
            
            var x = radius * Mathf.Sin(-angle / 2);
            var z = radius * Mathf.Cos(-angle / 2);
            Ray ray = new Ray(sectorTransform.position,
                sectorTransform.TransformPoint(new Vector3(x, 0, z)) -
                sectorTransform.position);

            var endPoint = Vector3.zero;
            if (Physics.RaycastNonAlloc(ray, hit, radius, mask) > 0)
            {
                endPoint = sectorTransform.InverseTransformPoint(new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z));
            }
            else
            {
                endPoint = position + new Vector3(x, 0, z);
            }
            var addPointA = new Vector3(position.x, position.y + 10f, position.z);
            var addPointB = new Vector3(endPoint.x, endPoint.y + 10f, endPoint.z);
            vertices.Add(position);
            vertices.Add(addPointA);
            vertices.Add(addPointB);
            vertices.Add(endPoint);
            indices.Add(0);
            indices.Add(3);
            indices.Add(1);
            indices.Add(3);
            indices.Add(2);
            indices.Add(1);

            //构建弧线范围
            var numbers = 3;
            for (var i = -angle / 2; i <= angle / 2; i += angleLength)
            {
                var lastPoint = vertices[vertices.Count - 1];

                x = radius * Mathf.Sin(i);
                z = radius * Mathf.Cos(i);
                ray = new Ray(sectorTransform.position,
                    sectorTransform.TransformPoint(new Vector3(x, 0, z)) -
                    sectorTransform.position);

                endPoint = Vector3.zero;
                if (Physics.RaycastNonAlloc(ray, hit, radius, mask) > 0)
                {
                    endPoint = sectorTransform.InverseTransformPoint(new Vector3(hit[0].point.x,hit[0].point.y + 0.1f,hit[0].point.z));
                }
                else
                {
                    endPoint = position + new Vector3(x, 0, z);
                }
                /*做一个墙一样的四顶点片，一共多添加4个顶点 6个index，uv待议
                 endpoint 当前点  lastpoint 上个点
                 *（添加点A）   *（添加点B）
                 | \           |
                 |   \         |
                 |     \       |
                 |       \     |
                 |         \   |
                 |           \ |
                 *（上个点）    *（当前点）
                */

                addPointA = new Vector3(lastPoint.x, lastPoint.y + 10f, lastPoint.z);
                addPointB = new Vector3(endPoint.x, endPoint.y + 10f, endPoint.z);

                vertices.Add(addPointA);
                vertices.Add(addPointB);
                vertices.Add(endPoint);

                indices.Add(numbers);
                indices.Add(numbers + 3);
                indices.Add(numbers + 1);
                indices.Add(numbers + 3);
                indices.Add(numbers + 2);
                indices.Add(numbers + 1);
                indices.Add(0);
                indices.Add(numbers + 3);
                indices.Add(numbers);

                numbers += 3;
              
            }
            
            //构建第二部分侧面decal
            var sectorLastPoint = vertices[vertices.Count - 1];
            endPoint = position;
            addPointA = new Vector3(sectorLastPoint.x, sectorLastPoint.y + 10f, sectorLastPoint.z);
            addPointB = new Vector3(endPoint.x, endPoint.y + 10f, endPoint.z);
            vertices.Add(addPointA);
            vertices.Add(addPointB);
            vertices.Add(endPoint);
            indices.Add(numbers);
            indices.Add(numbers+3);
            indices.Add(numbers+1);
            indices.Add(numbers+1);
            indices.Add(numbers+3);
            indices.Add(numbers+2);
            
            
        }
    }
}